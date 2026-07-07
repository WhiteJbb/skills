# Decision Memo: Data Warehouse Consolidation

**Recommendation:** Consolidate onto Snowflake. Start migration work immediately, but sequence it so PII tables move only in the narrow window after our September compliance audit closes and before the October 15 marketing freeze.

## Why Snowflake, not Redshift

Snowflake costs more today ($67K/mo vs $41K/mo), but the fact base points away from staying on Redshift long-term. On the one real apples-to-apples benchmark we have — the top 20 revenue dashboards — Snowflake ran 2.3s median vs Redshift's 4.1s. That's only 20 queries, and the broader "Snowflake is faster" claim is unbenchmarked, so I'm not leaning on it. What tips the decision is structural: the Redshift reserved-instance contract expires December 31 and renewal locks us in for another 12 months, and 2 of the 3 engineers who understand our custom Redshift ingestion framework have resignation dates in Q3. Staying on Redshift means either losing that institutional knowledge or renewing a 12-month contract we may regret. I'm also noting, not weighting, the $800K sunk cost in the ingestion framework — that money is spent regardless of what we decide next, and shouldn't drive this call.

## Timing constraints — this is the hard part

Three deadlines don't stack cleanly:
- **PII/compliance**: PII tables on Redshift sit inside an audit scope closing in September. Migrating them *before* the audit closes triggers re-certification (~$120K). Migrating after is cheaper — but only if it happens before...
- **Marketing freeze**: hard freeze on pipeline changes Oct 15–Jan 5.
- **RI contract**: expires Dec 31; missing this deadline means another 12-month lock-in.

That leaves a real window of roughly 6 weeks (post-September audit close to Oct 15) to migrate the PII tables, and a firm deadline of Dec 31 for everything else if we want to avoid renewal. Non-PII migration (340 dashboards, though only 128 were opened last quarter — worth pruning the rest rather than migrating dead dashboards) should start now, ahead of the Q3 engineer departures.

## What I don't know and am not assuming

Migration effort is disputed — platform team says 6 engineer-months, data team says 11 ("platform always lowballs"). I'm not picking a winner here; the plan should assume the higher estimate for staffing purposes. Redshift uptime is also unreconciled (98.7% per our review vs 99.6% per AWS's own report) — this doesn't change the recommendation but should be resolved before it's cited elsewhere. The $900K Snowflake discount tier is a modest upside if consolidation pushes us over that spend threshold, not a driver of the decision.

## Ask

Approve starting non-PII migration now, with PII migration locked to the Sept–Oct 15 window.
