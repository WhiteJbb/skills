# Salon Chain Scheduling System — Design

## Context & Assumptions

200 salons, ~10 stylists each → ~2,000 stylists. Booking volume is modest by internet standards (even 50 bookings/day/salon = ~10k/day, peak maybe tens of requests/second chain-wide). This is **not a scale problem; it's a correctness and business-policy problem**. So I optimize for a simple, transactionally correct core (single relational database) rather than distributed complexity we don't need.

Timezone note: store all times as UTC instants; salon-local rules (opening hours, stylist schedules) are stored as local time + salon timezone and expanded to UTC when materialized.

---

## 1. Data Model

Relational (PostgreSQL). Core tables:

```
salon(id, name, timezone, address, ...)

stylist(id, salon_id, name, active, ...)

service(id, name, base_duration_min, base_price)          -- catalog: cut=30, color=90, perm=120...
stylist_skill(stylist_id, service_id, duration_min, price) -- per-stylist override; row = "can do it"

-- Recurring weekly template
stylist_schedule(id, stylist_id, weekday, start_local, end_local, effective_from, effective_to)

-- Exceptions: vacations, sick days, one-off overtime
stylist_schedule_override(id, stylist_id, date, type ENUM(off, extra), start_local, end_local)

customer(id, phone, email, no_show_count, completed_count, reliability_score, ...)

appointment(
  id, salon_id, stylist_id, customer_id,
  start_at, end_at,                 -- UTC instants, end = start + Σ service durations
  status ENUM(pending_payment, confirmed, completed, cancelled, no_show),
  deposit_amount, deposit_status,
  created_at, version
)

appointment_service(appointment_id, service_id, seq, duration_min, price)
  -- ordered list; the multi-service booking is ONE appointment row spanning the total duration
```

Key decisions:

- **One appointment row per booking, even multi-service.** The services are back-to-back with the same stylist, so the schedulable unit is the contiguous interval `[start_at, end_at)`. `appointment_service` preserves the breakdown for pricing, receipts, and analytics. Modeling each service as a separate schedulable row invites gaps and partial-booking bugs.
- **Durations live on `stylist_skill`**, not just the catalog. A senior stylist does a cut in 25 min, a junior in 40. This directly affects availability math and must be per-stylist.
- **Exclusion constraint as the safety net** (see §3):
  ```sql
  ALTER TABLE appointment ADD CONSTRAINT no_overlap
    EXCLUDE USING gist (
      stylist_id WITH =,
      tstzrange(start_at, end_at) WITH &&
    ) WHERE (status IN ('pending_payment','confirmed'));
  ```
  The database itself makes double-booking impossible regardless of application bugs.

---

## 2. Real-Time Availability (Including Multi-Service)

**Reduce multi-service to single-interval search.** When a customer picks services {cut, color}, we:

1. Filter stylists at the chosen salon who have **all** requested skills (join on `stylist_skill`).
2. For each candidate stylist, compute `total = Σ stylist_skill.duration_min` in service order. The multi-service case is now identical to the single-service case: *find a free contiguous window of length `total`*.

**Per-stylist free-window computation** for a given day:

1. Expand `stylist_schedule` (+ overrides) into working intervals, e.g. `[10:00–14:00], [15:00–19:00]`.
2. Fetch that stylist's active appointments for the day (`status IN (pending_payment, confirmed)`) — including holds, so a slot mid-checkout doesn't show as available.
3. Subtract appointments from working intervals → free intervals.
4. For each free interval of length `L ≥ total`, emit candidate start times on a 15-minute grid: `start, start+15, …, last start where start+total ≤ interval end`.

This is a few rows and trivial interval arithmetic per stylist — cheap enough to compute **on demand from the source of truth**, per request.

**Caching:** cache the rendered availability per `(salon, service-set, date)` in Redis with a short TTL (30–60 s), invalidated on any booking/cancellation for that salon+date. Staleness is acceptable *only* because the display layer is not authoritative — the booking transaction re-validates (§3). A stale cache costs the customer one "sorry, just taken, here are alternatives" message, never a double-booking.

Deliberately **not** doing: precomputed slot tables (rows per 15-min slot). They're a denormalization that must be rebuilt on every schedule change and handle multi-service poorly (a 150-min booking spans 10 slot rows → multi-row locking pain). Interval math on demand is simpler and correct.

---

## 3. Preventing Double-Booking Under Concurrency

Three layers, cheapest first:

**Layer 1 — UX soft hold.** When a customer selects a slot and proceeds to checkout, create the appointment row immediately with `status = pending_payment` and a 7-minute TTL (background job expires it). The slot disappears from availability for everyone else during checkout. This makes the actual race window (two users clicking "reserve" the same instant) milliseconds instead of minutes.

**Layer 2 — transactional check-and-insert.** The booking write is one transaction:

```sql
BEGIN;
SELECT id FROM appointment
 WHERE stylist_id = :s
   AND status IN ('pending_payment','confirmed')
   AND tstzrange(start_at, end_at) && tstzrange(:start, :end)
 FOR UPDATE;                        -- if any row returns → 409 with alternatives
-- also re-check the stylist's schedule covers [:start, :end)
INSERT INTO appointment (...) VALUES (...);
COMMIT;
```

**Layer 3 — the exclusion constraint (§1) as the invariant.** Two truly simultaneous inserts can both pass Layer 2's check (neither sees the other's uncommitted row; `FOR UPDATE` can't lock a row that doesn't exist yet). The GiST exclusion constraint serializes exactly these conflicting inserts at the database level: one commits, the other gets a constraint violation, which the API maps to `409 Conflict` + freshly computed alternative slots.

Why this and not alternatives:
- **No distributed locks / Redis locks needed** — the contention domain is one stylist's calendar; a single Postgres handles our write volume with huge headroom, and DB-enforced invariants can't be bypassed by a buggy code path, a retry storm, or a second service writing to the table.
- **Not `SERIALIZABLE` isolation everywhere** — the exclusion constraint gives us the one serialization we need without retry-loop complexity on every transaction.
- Idempotency keys on the booking endpoint so a client retry after a network blip doesn't create two appointments.

---

## 4. No-Show Policy (15%)

15% no-show on, say, an $80 average ticket is ~$12 expected loss per booking — too much to ignore, but hard-line policies destroy top-line bookings. **Tiered friction based on customer history:**

1. **Deposit, tiered by risk and ticket size.**
   - New customers and anyone with a no-show in the last 6 months: deposit = 20% of booking value (min $10), applied to the bill; forfeited on no-show or cancellation < 12 h before.
   - Established reliable customers (≥3 completed, no recent no-shows): card on file required, **no upfront charge**, but a disclosed late-cancel/no-show fee (50% of service value) charged to the card.
   - High-value bookings (>2 h, e.g. color+perm): deposit required regardless of history.
2. **Reminder ladder** (cheap, proven to cut no-shows meaningfully): confirmation at booking → SMS at 24 h with one-tap *confirm / cancel / reschedule* → SMS at 3 h. Free rescheduling up to 12 h before makes cancelling *easy* — a slot released at T-24h is resellable; a silent no-show is not.
3. **Waitlist backfill.** Customers can join a waitlist for a full day; on cancellation, notify the top matches (skill + duration fit) with a claim link — the first to claim gets it, again protected by §3. This converts recovered cancellations into revenue rather than merely punishing no-shows.
4. **Repeat offenders** (2+ no-shows in 12 months): full prepayment required to book.

**Deliberately not doing overbooking** (airline-style). Unlike an airline seat, a stylist appointment can't bump a customer to the next flight — a collision means a walk-out and a public 1-star review. The expected-value math only works when the overflow cost is manageable; here it isn't.

**Risks introduced and mitigations:**

| Risk | Mitigation |
|---|---|
| Deposits deter new customers (booking-funnel drop-off) | Tiering: friction concentrates on unproven/risky segments; A/B the deposit amount per region and watch conversion vs. no-show rate |
| Charging cards triggers disputes/chargebacks | Explicit consent checkbox at booking, fee stated in every reminder SMS, salon manager can waive with one click (genuine emergencies) |
| Customers dispute "I did cancel" | All cancellations through the app/SMS link, timestamped server-side; phone cancellations logged by staff in the system |
| Stylist marks no-show incorrectly (customer was late) | Grace window: status can only become `no_show` ≥15 min after start; customer notified immediately with an appeal path |

---

## 5. Key Trade-offs

1. **Single Postgres + DB-enforced exclusion constraint, instead of a distributed reservation service.**
   Cost: a scaling ceiling and a single point of failure (mitigated by a replica + failover). Gain: the double-booking invariant lives in one place and cannot be violated by any code path. At ~10k bookings/day we are ~3 orders of magnitude below where this design strains; buying distributed-systems complexity now would be paying for scale we'll never reach while taking on the bugs today. Contention is naturally partitioned per stylist anyway, so hot-spotting is structurally impossible.

2. **Compute availability on demand (with short-TTL cache), instead of materialized slot inventory.**
   Cost: every availability request does live interval math; slightly higher read latency than a slot-table lookup. Gain: no rebuild pipeline when schedules change, and multi-service bookings of arbitrary total duration "just work" — a slot inventory hard-codes a granularity and makes variable-length bookings a multi-row consistency problem. The read work is trivial (one stylist-day is a handful of rows), and the cache absorbs browse traffic.

3. **Deposits/fees instead of overbooking for the no-show problem.**
   Cost: friction at booking time will lose some price-sensitive or commitment-shy customers, and it shifts effort onto policy tuning (tiers, amounts) rather than a purely algorithmic fix. Gain: overbooking's failure mode (two customers, one chair, no recovery path) is customer-facing and reputation-damaging, while a deposit's failure mode (some funnel drop-off) is measurable and tunable. Combined with the waitlist backfill, we recover much of the lost revenue without ever risking a collision.