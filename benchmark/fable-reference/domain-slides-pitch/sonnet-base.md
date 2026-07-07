## The on-call problem is measurable and getting worse
14 engineers, 2 teams. 3.2 pages/night each; 41% false positives (6-month sample, 4,120 pages).

## Triage, not alerting, is the bottleneck
MTTA is fine (9 min). MTTR averages 74 min — mostly manual triage and context gathering.

## Burnout is already costing us engineers
5 of the last 9 engineering leavers cited on-call burden as a primary reason for leaving.

## And attrition is expensive
[exhibit: cost comparison bar chart — $140K to backfill one senior platform engineer vs. $180K pilot cost]

## Nightshift: what it does
Auto-triages alerts, dedupes storms, attaches runbook context. Vendor claims 60% page reduction.

## We already tested it ourselves
2-week shadow test, one service: 38% page reduction, 0 missed critical alerts — every suppressed page verified non-actionable.

## The pilot proposal
2 teams, 12 weeks, $180K total (license + integration engineering time).

## How we'll know it worked
[exhibit: success criteria checklist — ≥30% page reduction, 0 missed Sev-1, MTTR −20%, satisfaction +1 point]

## Risks and how we manage them
Over-trust of auto-suppression: weekly suppression audit. Legacy pager integration: ~3 weeks, one engineer.

## What this sets up
If successful, full rollout ~$520K/yr, offset by 1-2 fewer attrition backfills/yr plus reclaimed engineer-hours.

## The ask
Approve the $180K, 12-week Nightshift pilot this quarter for the 2 platform on-call teams.
