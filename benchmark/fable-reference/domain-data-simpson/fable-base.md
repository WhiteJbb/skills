# Did signup conversion improve after the 2026-03-01 pricing change?

## Answer: No — despite appearances

Overall conversion rose from **5.08%** (pre: 3,224 signups / 63,510 visitors, 2026-01-05 to 2026-02-28) to **5.83%** (post: 4,081 / 70,002, 2026-03-01 to 2026-04-25). Taken at face value, that is a +0.75pp improvement.

But this is Simpson's paradox. Split by segment, conversion **fell in both segments**:

| Segment | Pre conv. | Post conv. | Change |
|---|---|---|---|
| Enterprise | 3.02% (1,119 / 37,073) | 2.60% (534 / 20,553) | −0.42pp |
| SMB | 7.96% (2,105 / 26,437) | 7.17% (3,547 / 49,449) | −0.79pp |
| **Overall** | **5.08%** | **5.83%** | **+0.75pp** |

The overall increase is entirely a traffic-mix effect: SMB (the higher-converting segment) went from 41.6% of visitors pre-change to 70.6% post-change, while Enterprise traffic roughly halved. More visitors landed in the high-conversion segment, but every segment converted *worse* than before.

## Data-quality issues and handling

Starting from 230 data rows, I excluded:

- **8 exact duplicate rows** (identical date/segment/visitors/signups) — likely double-logged; kept one copy of each.
- **6 rows with blank `signups`** (2026-01-27 SMB; 2026-02-12, 2026-02-25 Enterprise; 2026-03-16 SMB; 2026-03-18, 2026-03-24 Enterprise) — excluded rather than imputed, since signups is the outcome being measured.

No negative values, zero-visitor rows, or rows with signups > visitors were found. Final dataset: 216 rows (107 pre, 109 post), balanced across segments (107 Enterprise, 109 SMB). `sales.csv` was not modified.

## Recommendation

Do not report the pricing change as a conversion win. Segment-level conversion declined for both Enterprise (−0.42pp) and SMB (−0.79pp); the headline improvement comes only from a shift in visitor mix toward SMB. Two follow-ups:

1. **Investigate why per-segment conversion dropped** — the new pricing may be deterring signups within each segment, which the blended number hides.
2. **Understand the traffic-mix shift** — determine whether the surge in SMB visitors (and drop in Enterprise) was caused by the pricing change itself or by concurrent marketing/seasonal factors, since the overall metric is now highly sensitive to mix.

Track conversion by segment going forward; the blended rate is misleading here.
