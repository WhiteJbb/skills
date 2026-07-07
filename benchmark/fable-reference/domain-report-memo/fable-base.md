# Decision Memo: Warehouse Consolidation

**To:** CTO · **Re:** Redshift vs. Snowflake consolidation

## Recommendation

Consolidate onto **Snowflake**, with migration sequenced to finish before the Oct 15 freeze and to let the Redshift reserved-instance contract lapse on Dec 31. Do not renew Redshift.

## Why Snowflake

- **Cost logic favors exit, not renewal.** We pay $41K/mo for Redshift plus $67K/mo for Snowflake. Consolidating eliminates the $41K/mo (~$492K/yr) and pushes Snowflake annual spend past the $900K threshold that unlocks our negotiated 20% discount tier.
- **Performance.** Our only real benchmark — top-20 revenue dashboards — shows median runtime 2.3s on Snowflake vs. 4.1s on Redshift. (The broader "Snowflake is faster" belief is unbenchmarked; the 20-query result is the fact.)
- **The Redshift knowledge base is evaporating.** Two of the three engineers who know the custom ingestion framework resign in Q3. Every quarter we stay on Redshift, operating it gets riskier, independent of cost.
- **Scope is smaller than it looks.** 340 dashboards point at Redshift, but only 128 were opened last quarter. We should migrate the ~128 and formally deprecate the rest.

## Timing constraints — this is the hard part

Three dates collide: the PII audit closes in **September** (migrating PII earlier triggers ~$120K re-certification), the marketing hard freeze runs **Oct 15 – Jan 5**, and the Redshift contract expires **Dec 31** (renewal locks 12 months). Plan:

1. **Now – Sept:** Migrate non-PII, non-marketing workloads; capture knowledge from the departing engineers before their Q3 exit dates. Do not touch PII tables.
2. **Sept – Oct 15:** Migrate PII tables immediately after audit close (avoiding the $120K), plus remaining dashboards.
3. **Oct 15 – Dec 31:** Freeze-compliant tail only. Anything not done by Oct 15 waits.

**Residual risk:** if migration slips past Oct 15, we cannot finish by Dec 31. Then negotiate a short on-demand extension for a skeleton Redshift footprint through early January — costly per-month, far cheaper than a 12-month lock-in.

## Facts vs. assumptions vs. open conflicts

- **Facts (from the notes):** spend figures, benchmark result, contract/audit/freeze dates, attrition, dashboard usage audit, discount tier.
- **Assumptions:** that the ~212 unused dashboards can be deprecated without pushback; that a short contract extension is negotiable.
- **Unresolved conflicts:** migration effort is **6 vs. 11 engineer-months** (platform vs. data team — staff to the 11); Redshift Q1 uptime is **98.7% vs. 99.6%** (internal vs. vendor, never reconciled — not decision-critical).
- **On the $800K ingestion framework:** that is sunk cost. It should inform migration effort estimates, not the platform decision.

**Ask:** approve Snowflake consolidation and staff to the 11-engineer-month estimate this week — the Sept–Oct 15 window is narrow and the people who can do it are leaving.
