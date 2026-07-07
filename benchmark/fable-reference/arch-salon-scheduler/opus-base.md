# Salon Scheduling System — Design

## Context & key decisions up front
- 200 salons, each with its own stylists, hours, and chairs. I treat the **salon** as the unit of locality: bookings are salon-scoped, so contention and availability computation partition cleanly by salon.
- Backing store: **PostgreSQL** (one logical DB, partitioned by salon where it matters). Chosen because I need row-level locking and transactional integrity for the double-booking problem, and the data volume (~200 salons × ~15 stylists × ~40 appointments/day ≈ 120K appts/day) is trivially within a single Postgres cluster's reach.

---

## 1. Data Model

```
Salon(id, name, timezone, address)

Stylist(id, salon_id, name, active)

Service(id, salon_id, name, default_duration_min, price)          -- cut, color, perm...

StylistSkill(stylist_id, service_id, duration_override_min NULL)  -- which services a
                                                                  -- stylist can do,
                                                                  -- and how fast

WorkingHours(id, stylist_id, weekday, start_time, end_time)       -- recurring weekly
TimeOff(id, stylist_id, start_ts, end_ts, reason)                 -- vacation, breaks,
                                                                  -- one-off exceptions

Appointment(id, salon_id, stylist_id, customer_id,
            start_ts, end_ts,               -- overall span (back-to-back services)
            status,                         -- pending, confirmed, in_progress,
                                            -- completed, no_show, cancelled
            deposit_status, created_at)

AppointmentService(appointment_id, service_id, seq, duration_min) -- ordered list of
                                                                  -- services in one appt

Customer(id, name, phone, email, no_show_count, total_bookings, reliability_score)
```

Design notes:
- **`AppointmentService` is an ordered list** (`seq`) so a "color + cut" appointment is two rows performed back-to-back by one stylist. The parent `Appointment` carries the *aggregate* `[start_ts, end_ts)`; that aggregate is what all availability and conflict checks operate on, which keeps those checks simple (one interval per stylist).
- Duration lives on the `StylistSkill` (with a service default fallback) because a senior stylist genuinely does a color faster — availability must reflect the actual stylist doing the work.
- `WorkingHours` is the recurring template; `TimeOff` is the exception overlay. Real availability = template minus exceptions minus existing appointments.
- Customer keeps `reliability_score` denormalized to drive the no-show policy (§4) without a join-heavy computation at booking time.

---

## 2. Real-Time Availability (including multi-service)

**Input:** stylist (or "any stylist with the skills"), an ordered list of requested services, a target date.

**Step 1 — required duration.** Sum the per-stylist durations of the requested services:
`total = Σ StylistSkill.duration_override ?? Service.default_duration`. This single number collapses the multi-service case into "I need a contiguous block of length `total`."

**Step 2 — build the free/busy timeline for that stylist/day.**
1. Start with `WorkingHours` for that weekday → the base open interval(s).
2. Subtract `TimeOff` intervals that overlap the day.
3. Subtract existing `Appointment [start_ts, end_ts)` for that stylist where status ∈ {pending, confirmed, in_progress}.
   The result is a set of **free gaps**.

**Step 3 — slot generation.** Slide a window of length `total` across each free gap at the salon's slot granularity (e.g. 15 min), respecting a **buffer/cleanup minutes** setting between appointments. Every window position that fits entirely inside a gap is an offered start time. Because we pre-summed to one block, the multi-service appointment is guaranteed contiguous and single-stylist by construction — no partial/split bookings.

**Step 4 — "any stylist" queries** run Step 2–3 per eligible stylist (those with all required `StylistSkill`s) and union the offered slots, tagging each with the stylist who can serve it.

**Performance:** availability is a read. Cache the per-stylist free/busy timeline in Redis keyed `(stylist_id, date)`, invalidated on any write to that stylist's appointments/time-off. Booking screens hit the cache; the authoritative check happens at commit time (§3), so a slightly stale cache only costs an occasional retry, never a double-book.

---

## 3. Preventing Double-Booking Under Concurrency

Availability caches can be stale, and two customers can click the same slot in the same millisecond. Correctness must live in the database, not the UI. Two layers:

**Layer 1 — hard invariant via exclusion constraint (the real guarantee).**
Add a Postgres `btree_gist` **exclusion constraint** on `Appointment`:

```sql
EXCLUDE USING gist (
  stylist_id WITH =,
  tstzrange(start_ts, end_ts) WITH &&
) WHERE (status IN ('pending','confirmed','in_progress'));
```

This makes it **physically impossible** for two active appointments of the same stylist to overlap — the database rejects the second insert. No amount of concurrency, retries, or application bugs can violate it. This is the backbone.

**Layer 2 — transaction flow.**
1. Begin transaction.
2. Re-verify availability (working hours, time-off, buffers) reading the current rows — this catches business-rule violations the exclusion constraint doesn't know about.
3. `INSERT` the appointment (status `pending`).
4. If the exclusion constraint throws a conflict → the slot was taken in the race; **catch it, return "slot no longer available," and refresh the availability view.** The loser is told to pick again.
5. Commit.

I deliberately use an **exclusion constraint rather than app-level locking or optimistic version columns**: it is declarative, cannot be forgotten on a new code path, and pushes the guarantee to the one place all writers must pass through. Under the "same instant" scenario, exactly one insert wins and the others get a clean, catchable error.

For the "any stylist" case, the race resolves naturally: the loser can be silently retried against the next available stylist before surfacing an error, improving conversion.

---

## 4. No-Show Policy (~15%) and Its Risks

15% no-shows is the single biggest revenue leak. I layer cheap-and-friendly measures first, money measures second, and only then structural ones.

**A. Reminders + easy self-service cancel (reduces the rate).**
- SMS/email at 24h and 2h before. One tap to confirm or reschedule.
- Frees slots early enough to rebook. Expected to cut no-shows meaningfully at near-zero cost and no customer friction. This is the first line and applies to everyone.

**B. Deposits, targeted by reliability (recovers the revenue).**
- Compute `reliability_score` from `no_show_count / total_bookings`.
- **New customers and repeat no-show customers** must prepay a **deposit** (e.g. 20–30% or a flat fee) to confirm; trusted regulars book with no deposit.
- No-show → deposit is forfeited (applied to the lost revenue). Show up → deposit applies to the bill.
- Targeting deposits by risk avoids punishing loyal customers while covering the actual risky bookings.

**C. Controlled overbooking on high-risk, high-demand slots (recovers utilization).**
- For peak slots that historically no-show, allow a *small*, bounded overbook (e.g. permit 1 standby on a slot whose stylist's segment shows ≥X% historical no-show), **only** for services short enough to absorb.

**Risks introduced and how I bound them:**
- **Deposits depress conversion / bookings.** Mitigation: apply them only to unproven or proven-unreliable customers, keep the amount modest, and make it fully credited toward the service.
- **Overbooking can produce a real double-arrival** — a furious customer waiting with no chair. This is the dangerous one. Mitigation: overbook is **opt-in per salon, capped at 1, disabled by default**, never applied to long/premium services, and paired with a compensation script (priority rebooking + discount). Given the pain of a mishandled overbook, I treat A and B as the primary levers and C as a cautious, per-salon experiment — not a default.
- **Chargeback/dispute overhead** on forfeited deposits. Mitigation: clear cancellation-window policy shown at booking, and a grace window (free cancel up to N hours before).

---

## 5. Most Important Trade-offs

**1. Correctness pushed into the database (exclusion constraint) over performance-oriented app-level coordination.**
I could have used lighter-weight optimistic concurrency or a booking queue for throughput. I chose a DB-enforced overlap constraint because a double-booked stylist is a *visceral, trust-destroying* failure, and 120K appts/day is nowhere near needing to trade away that guarantee for scale. Correctness first; the volume doesn't force the compromise.

**2. Availability is a cached, best-effort read; the booking commit is the source of truth.**
Rather than trying to keep availability perfectly consistent everywhere (expensive, and impossible across concurrent clients anyway), I let the browse-time view be fast and occasionally stale, and make the *commit* authoritative with a catch-and-retry on conflict. This buys snappy UIs and simple caching at the cost of an occasional "slot just taken" message — the right trade for a booking product.

**3. Pre-summing multi-service into one contiguous block over modeling per-service sub-slots.**
Treating a multi-service appointment as a single `[start,end)` block on one stylist makes availability, conflict detection, and the exclusion constraint dramatically simpler and keeps every service with the same stylist back-to-back (the stated requirement). The cost is reduced packing flexibility — I can't interleave another customer between a color's processing time. That flexibility is rarely worth the large jump in modeling and concurrency complexity it would require, so I keep the block model.

**4. (No-show) risk-targeted friction over a blanket policy.**
Universal deposits would maximize revenue protection but suppress bookings and alienate regulars; no policy leaves 15% on the table. Segmenting by `reliability_score` captures most of the recovered revenue while concentrating the friction on exactly the bookings that cause the problem.