# Raw notes — warehouse consolidation question (collected by EA, unsorted)

- Monthly spend: legacy Redshift cluster $41K/mo, Snowflake $67K/mo. Finance wants one platform.
- Platform team estimate to migrate everything off Redshift: 6 engineer-months. Data team's own estimate for the same migration: 11 engineer-months ("platform team always lowballs").
- 340 dashboards still point at Redshift. Usage audit last quarter: 128 of them opened at least once.
- Ops quarterly review: Redshift uptime Q1 was 98.7%. (The AWS account report the vendor sent claims 99.6% for the same period — nobody has reconciled these.)
- Everyone agrees Snowflake queries are faster. (No benchmark attached to this claim.)
- The one real benchmark we have: top-20 revenue dashboards re-run on both, median runtime 4.1s Redshift vs 2.3s Snowflake. Only covers those 20 queries.
- We spent about $800K over three years building the custom ingestion framework on the Redshift side. CFO keeps bringing this up.
- Compliance: the PII tables on Redshift are inside an audit scope that closes in September. Migrating them before the audit closes means re-certifying the new environment, external assessor quoted ~$120K.
- Redshift reserved-instance contract expires Dec 31. Renewal locks us for 12 months at current rates.
- Attrition: 2 of the 3 engineers who know the legacy ingestion framework have resignation dates in Q3.
- Snowflake credits negotiated last year include a 20% discount tier if annual spend crosses $900K.
- (Unrelated: office move to Building C slips to November; recruiting says the data-eng req is finally approved.)
- Marketing analytics team says "do not touch our pipelines during Q4 campaign season, hard freeze Oct 15 – Jan 5."
