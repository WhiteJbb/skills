# Briefing pack — "Nightshift" on-call automation pilot

Audience: VP Engineering + CFO delegate. Slot: 10 minutes. Decision sought: approve a $180K pilot budget this quarter.

Facts (from our own logs and the vendor eval, 6 months of data):

- Platform org on-call rotation: 14 engineers across 2 teams.
- Average 3.2 pages per night per on-call engineer; 41% of pages are false positives (measured, 6-month sample of 4,120 pages).
- MTTA is fine (9 min) but MTTR averages 74 min — most of it is manual triage and context gathering.
- Exit interviews: 5 of the last 9 engineering leavers cited on-call burden as a primary reason.
- Backfilling one senior platform engineer costs roughly $140K in recruiting + ramp.
- Nightshift (vendor) auto-triages alerts, dedupes storms, attaches runbook context. Vendor claims 60% page reduction.
- Our own 2-week shadow test on one service: 38% page reduction, 0 missed critical alerts (every suppressed page was independently verified non-actionable).
- Pilot proposal: 2 teams, 12 weeks, $180K total (license + integration engineering time).
- Proposed success criteria: ≥30% page reduction, 0 missed Sev-1, MTTR −20%, on-call satisfaction survey +1 point.
- Risks: over-trust of auto-suppression (mitigation: weekly suppression audit); integration with the legacy pager takes ~3 weeks of one engineer.
- If pilot succeeds, full rollout next year ~$520K/yr; expected offset: 1-2 fewer attrition backfills/yr + reclaimed engineer-hours.
