# Signup Conversion After the 2026-03-01 Pricing Change

## Answer: Overall conversion rose, but this is a Simpson's paradox — every segment actually got worse.

Aggregated across all rows, conversion (signups/visitors) went from **5.08% pre-change** to **5.83% post-change** (Jan 5 – Feb 28 vs. Mar 1 – Apr 25). Taken at face value this looks like an improvement. But broken out by segment, the opposite happened:

- **Enterprise**: 3.02% → 2.60% (down 0.42 pts)
- **SMB**: 7.96% → 7.17% (down 0.79 pts)

Both segments converted *worse* after the pricing change. The overall number improved only because the visitor mix shifted heavily toward SMB, which converts far better than Enterprise regardless of period:

- Enterprise share of visitors: 58% pre → 29% post
- SMB share of visitors: 42% pre → 71% post

Since SMB has a structurally higher conversion rate, sending relatively more traffic to SMB pulls the blended average up even though neither segment's own performance improved. The correct read is that the pricing change is associated with a **decline** in conversion within both customer segments.

## Data-quality issues found and handling

1. **8 exact duplicate rows** (identical date/segment/visitors/signups) — likely a logging/export glitch. Removed duplicates before analysis (230 → 222 rows).
2. **6 rows with missing `signups`** (empty string, visitors present) — no reliable way to impute, so these rows were excluded from conversion calculations (222 → 216 rows used).
3. No rows had signups > visitors, no non-numeric visitor values, and no conflicting duplicate entries (same date/segment with different numbers) — checked and clean.
4. Visitor counts (333–976/day) and per-row conversion rates (2.2%–8.4%) look like a plausible, non-outlier range — no evidence of data entry errors there.

## Recommendation

Don't report the headline 5.08% → 5.83% lift to leadership — it's an artifact of the traffic mix shifting toward SMB, not a pricing win. Report conversion **by segment**, both of which declined slightly after the change. Investigate why Enterprise conversion dropped 0.4 pts and SMB dropped 0.8 pts (e.g., did the new pricing raise Enterprise price points or add friction?) before deciding whether to keep, adjust, or roll back the change. Also worth checking why Enterprise traffic volume itself fell by roughly half post-change, since that shift is doing most of the work in the aggregate number.
