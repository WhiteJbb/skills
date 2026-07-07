## Nightshift Pilot: Fix On-Call Before It Costs Us Another Engineer

Ask today: approve a $180K, 12-week pilot to automate on-call triage for 2 platform teams. 10 minutes, one decision.

## The Problem: On-Call Is Burning People, Not Just Time

14 engineers rotate on-call across 2 teams. Each averages 3.2 pages per night — and 41% are false positives.

[exhibit: bar chart — 4,120 pages over 6 months, split 59% actionable vs 41% false positive]

## False Alarms at Scale

41% false positives isn't noise — it's 6 months of measured data across 4,120 pages. Nearly half of every night's interruptions are for nothing.

## Response Is Fast; Resolution Is Slow

MTTA is healthy at 9 minutes. MTTR averages 74 minutes — dominated by manual triage and context gathering. That's the automatable part.

[exhibit: timeline bar — 9 min acknowledge vs 74 min resolve, triage/context segment highlighted]

## The Real Cost: Attrition

Exit interviews: 5 of our last 9 engineering leavers cited on-call burden as a primary reason. Backfilling one senior platform engineer runs ~$140K in recruiting and ramp.

## What Nightshift Does

Auto-triages alerts, dedupes alert storms, attaches runbook context to each page. Vendor claims 60% page reduction.

## We Didn't Take the Vendor's Word

Our own 2-week shadow test on one service: 38% page reduction, 0 missed critical alerts. Every suppressed page was independently verified non-actionable.

[exhibit: table — vendor claim 60% vs our shadow test 38% reduction, 0 missed criticals]

## The Pilot

2 teams, 12 weeks, $180K total — license plus integration engineering time. Legacy pager integration takes ~3 weeks of one engineer.

## Success Criteria — Measurable, Pre-Committed

≥30% page reduction. 0 missed Sev-1. MTTR down 20%. On-call satisfaction up 1 point. Miss them, we stop.

## Risk and Mitigation

Main risk: over-trusting auto-suppression. Mitigation: weekly suppression audit — same verification discipline as the shadow test.

## The Economics

Full rollout, if the pilot succeeds: ~$520K/yr next year. Expected offset: 1–2 fewer attrition backfills per year (~$140K each) plus reclaimed engineer-hours.

[exhibit: table — $520K/yr rollout cost vs offset from avoided backfills + reclaimed hours]

## The Ask

Approve $180K this quarter for the 12-week, 2-team pilot. Pre-agreed success criteria decide go/no-go on rollout. Decision today.
