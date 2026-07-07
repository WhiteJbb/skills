# Decision Memo: Data Warehouse Consolidation

**Recommendation:** Consolidate onto Snowflake, decommissioning Redshift. Do not renew the Redshift reserved-instance (RI) contract at its December 31 expiration. Sequence the migration in two windows — general workloads now through Q3, PII/compliance tables in September after the audit closes — because the Q4 marketing freeze and looming attrition leave no other viable path.

**Why Snowflake.** Cost favors Snowflake at scale: spend is currently split $41K/mo Redshift vs. $67K/mo Snowflake, but crossing $900K in annual Snowflake spend unlocks a 20% credit discount — a threshold the combined workload would likely reach post-migration. On performance, the only real benchmark (top-20 revenue dashboards) shows Snowflake at 2.3s median vs. 4.1s on Redshift; the broader claim that "Snowflake is faster across the board" is unsupported and should be treated as assumption, not fact. Redshift's $800K sunk cost in custom ingestion tooling, which the CFO keeps raising, is a sunk cost and shouldn't factor into a forward-looking decision.

**Why now, and why this sequencing.** Two forcing functions make delay costly. First, 2 of the 3 engineers who understand the legacy Redshift ingestion framework have resignation dates in Q3 — after they leave, migrating that framework gets materially harder, so non-PII migration work needs to start immediately. Second, the Redshift RI contract expires December 31 and auto-renewal locks us in for another 12 months; letting that deadline pass without a plan means paying for a platform we've already decided to leave.

The PII tables carry a separate constraint: they sit inside a compliance audit scope closing in September. Migrating them before the audit closes would require re-certifying the new environment at ~$120K — an avoidable cost if we simply wait until the audit closes in September, then migrate PII in the narrow window before the marketing team's hard freeze (Oct 15–Jan 5, non-negotiable per that team).

**What this timeline cannot promise.** The data team's estimate for full migration is 11 engineer-months, vs. platform team's 6-month estimate (which data team calls optimistic — unresolved conflict). Between now and Oct 15, we have roughly one quarter of engineering time, minus the attrition risk above. Full migration is unlikely to finish by December 31. Recommendation: don't sign a new 12-month RI; negotiate a short-term or month-to-month Redshift extension to bridge the freeze, targeting cutover by February.

**Open item:** Redshift uptime is reported as 98.7% (ops) vs. 99.6% (vendor) for the same quarter — unreconciled. Clarify before citing either figure externally; it doesn't change this recommendation.

claims: 13 (DATA 11 / SOURCE 0 / ASSUMPTION 2) | sections cut: 1 (office move/recruiting note — irrelevant to thesis) | figures consistent: Y
