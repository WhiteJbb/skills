# Warehouse Consolidation: Recommendation

**Recommendation:** Consolidate onto Snowflake and retire Redshift. Start migration now, phased around three external deadlines — the September audit close, the Oct 15–Jan 5 marketing freeze, and the Dec 31 Redshift reserved-instance renewal — rather than waiting for a single clean migration window, which doesn't exist.

**The cost case.** We pay for both platforms today: $41K/mo on Redshift plus $67K/mo on Snowflake. Dropping Redshift removes $41K/mo directly. Separately, our Snowflake contract unlocks a 20% discount tier past $900K annual spend; folding Redshift's workload in is likely to cross that line, partly offsetting the added usage — though we lack a post-migration bill estimate, so this is directional, not confirmed. The $800K sunk into the Redshift ingestion framework, which the CFO keeps raising, is a sunk cost and shouldn't weigh on this decision.

**Performance and scope.** The only real benchmark we have — 20 top revenue dashboards run on both platforms — shows Snowflake at 2.3s median vs Redshift's 4.1s. The broader claim that "Snowflake is faster" is team consensus with no benchmark behind it and should be treated as unverified. On scope: 340 dashboards point at Redshift, but last quarter's usage audit shows only 128 were actually opened. Migration planning should size to that active set, not the full 340.

**Unresolved conflicts.** Redshift uptime is disputed — ops reports 98.7% for Q1, the vendor's report claims 99.6%, unreconciled. Migration effort estimates also disagree: platform team says 6 engineer-months, data team says 11 ("platform team always lowballs"). Plan to the higher number; a downward surprise beats a shortfall.

**Why now, not later.** Three deadlines force the timeline: the Redshift RI contract renews Dec 31 and locks in 12 more months if not cancelled beforehand; 2 of the 3 engineers who understand the legacy ingestion framework have resignation dates in Q3, so their knowledge has to be captured or the work done before they leave; and the PII tables sit inside an audit scope closing in September — migrating them earlier triggers a ~$120K re-certification, so they should move only after the audit closes, and before the Oct 15 freeze if that window holds, otherwise after Jan 5.

**Staged plan:**
1. **Now–September:** migrate active, non-PII dashboards and pipelines while the departing engineers can still transfer ingestion knowledge.
2. **Post-audit (Sept) to Oct 15:** migrate PII/audit-scoped tables in the narrow window before the freeze; if that's not enough time, defer to after Jan 5.
3. **By November:** decide on non-renewal of the Redshift RI ahead of the Dec 31 deadline.

**Ask:** approve consolidation onto Snowflake, approve Phase 1 starting immediately, and approve non-renewal of the Redshift RI contract by December.
