## On-call load across the platform org is unsustainable: 14 engineers, 3.2 pages per night.

2 teams, 14 engineers, averaging 3.2 pages per on-call engineer per night — measured over a 6-month, 4,120-page sample.

## 41% of those pages are false positives, and triage — not detection — drives our 74-minute MTTR.

MTTA is a healthy 9 min; MTTR averages 74 min, mostly manual triage and context gathering, not alerting delay.

## On-call burden is now a leading cause of engineer attrition, at real cost.

5 of the last 9 engineering leavers cited on-call burden; backfilling one senior platform engineer costs roughly $140K.

## We didn't take the vendor's 60% page-reduction claim on faith — we tested it ourselves.

Nightshift auto-triages alerts, dedupes storms, and attaches runbook context; vendor claims 60% page reduction.

## Our own 2-week shadow test cut pages 38% with zero missed critical alerts.

[exhibit: bar chart comparing baseline vs. shadow-test page volume on one service — 38% reduction, 0 missed Sev-1 annotated]

## A 12-week, two-team pilot lets us validate that result at scale before committing further.

Pilot: 2 platform teams, 12 weeks, $180K total for license plus integration engineering time.

## We'll judge success against four criteria set in advance, not vibes.

[exhibit: criteria table — ≥30% page reduction, 0 missed Sev-1, MTTR −20%, on-call satisfaction survey +1 point]

## The main risk is over-trusting auto-suppression, and we already have a mitigation.

Risk: over-trust of auto-suppression. Mitigation: weekly suppression audit reviewing every suppressed page.

## Integration is a bounded 3-week task, not an open-ended engineering commitment.

Connecting Nightshift to our legacy pager takes roughly 3 weeks of one engineer's time.

## If the pilot succeeds, full rollout pays for itself in saved attrition and reclaimed hours.

Full rollout: ~$520K/yr, offset by 1–2 fewer attrition backfills/yr plus reclaimed engineer-hours from lower MTTR.

## Ask: approve the $180K, 12-week Nightshift pilot for the platform org this quarter.

Decision needed today: fund the pilot now so results are in before next year's rollout budgeting.
