# Decision Memo: Data Warehouse Consolidation

**To:** CTO
**Re:** Redshift vs. Snowflake — consolidate, and on what timeline

## Recommendation

Consolidate onto Snowflake. Let the Redshift reserved-instance contract lapse at its December 31 expiry rather than renew for another 12-month lock-in, and run the migration in the window between now and the Q4 pipeline freeze.

## Why Snowflake, not Redshift

The only head-to-head performance data we have — a benchmark of the top 20 revenue dashboards — shows Snowflake at 2.3s median runtime versus 4.1s on Redshift. That's real evidence, though it covers just 20 queries; the broader claim that "Snowflake is faster across the board" is unsupported and should not be treated as fact. The stronger argument is structural: two of the three engineers who understand the legacy Redshift ingestion framework have resignation dates in Q3. That framework cost roughly $800K to build over three years, but sunk cost is not a reason to keep it — the relevant fact is that the institutional knowledge to maintain it is leaving, and continuing on Redshift means re-building that expertise from scratch anyway.

Cost is not a clean argument either way. Redshift currently runs $41K/mo versus Snowflake's $67K/mo — cheaper today — but Snowflake's negotiated 20% discount tier kicks in above $900K/year in spend, which full consolidation would likely cross. We don't have a total post-migration cost estimate, so treat the discount as a mitigant, not a driver.

Two points in the notes are flagged as unresolved and shouldn't be relied on: Redshift uptime is reported as 98.7% internally and 99.6% by the vendor, with no reconciliation; and migration effort estimates range from 6 engineer-months (platform team) to 11 (data team, who distrust the platform team's number). Budget to the higher, 11-month estimate given the disagreement and the team closest to the legacy code's skepticism.

## Timeline

Scope reduction: only 128 of 340 dashboards pointed at Redshift were actually opened last quarter — migrate those first, not all 340, which meaningfully cuts the 6–11 month estimate.

Two hard constraints bound the schedule: the PII tables sit inside a compliance audit scope that closes in September, and migrating them earlier triggers a ~$120K re-certification cost — so move PII last, after the audit closes. Then the marketing team's hard freeze runs October 15 to January 5, during which no pipeline changes can happen. That leaves a narrow active window — now through mid-October — to do the bulk of the migration, with PII work squeezed into the short gap between the September audit close and the October 15 freeze. Do not renew the Redshift RI at its December 31 expiry regardless of how much migration remains; running residual Redshift workload on-demand for a few months is cheaper than another 12-month commitment to a platform we're exiting.
