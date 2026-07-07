---
name: summary-boost
description: Faithful-summary harness — inventory every load-bearing claim BEFORE writing, map each to kept/dropped, re-verify every number and quote against the source, then run an omission sweep over what the summary left out. Use at the START of any document/thread/meeting/paper summarization task when running on Sonnet or Opus. Skip one-paragraph inputs.
---

# Summary Boost

Blocks the 4 causes of bad summaries: mid-document omission, unfaithful paraphrase, document-order copying, purpose-blind compression. Coverage is counted, not felt.

## Language
User-facing responses in Korean. The summary itself follows the requested language (default: source language).

## 1. Purpose contract (before reading in full)
- One line: reader / what they will DO with the summary / target length. Unstated → pin it yourself and say so.
- Ranking rule: order by what changes the reader's action, never by document order.
- Materiality comes from the reader's DECISION, not from any category list in the request: a fact that would change the decision is load-bearing even if no listed category names it. Category lists are a floor, never a ceiling (measured: contract-literal reading of an incomplete category list dropped the two facts that motivated the whole proposal).

## 2. Inventory (before writing a single summary sentence)
- Work internally: build the inventory and iterate drafts in your reasoning, never in visible output or files — surface ONLY the final summary plus the 3-line report (measured: surfacing process cost 5.6x baseline tokens for zero coverage gain).
- Segment the source into countable units (sections, arguments, decisions, findings). Number them — this is the coverage denominator N.
- Scale the inventory to the source (measured: per-claim inventory on a 2-page doc cost 5x baseline tokens for no coverage gain): under ~3 pages, one line per SECTION (claims + figures together); per-claim lines only for longer sources. Long docs (10+ pages): delegate segment inventories to parallel Explore subagents; take back numbered claim lists, never raw dumps.
- Mark each unit load-bearing (dropping it changes the reader's understanding) or droppable. Dropping a load-bearing unit is a contract violation, not a style choice.
- A unit's figures are part of the unit: keeping a load-bearing risk/claim while cutting its magnitude IS dropping load-bearing content (measured: kept "labor risk" but cut the headcount while secondary figures survived).

## 3a. Budget policy under a hard length cap (breadth before richness)
Measured failure: caveat-rich prose crowds out exactly one load-bearing fact per run while secondary qualifiers survive. So:
- Draft lean first: ONE plain sentence per load-bearing unit (its core figure included), covering ALL of them, before ANY unit gets qualifiers, comparisons, or secondary figures.
- Spend leftover budget in this order: critical modality ("may", "not", "except") → secondary figures → comparisons/context. Over budget → cut in reverse order; facts are cut only after every qualifier is gone.
- Done-check: count load-bearing units in the draft against the inventory BEFORE polishing prose. Write the file once; at most ONE sweep-fix revision. No repeated full rewrites.

## 3. Write
- Conclusion/upshot first, then supporting points by importance.
- Every number, date, name, and attributed stance is re-looked-up in the source AT WRITE TIME — never from memory of the first read.
- Modality survives compression exactly: "may", "failed to", "except when". A dropped negation or caveat is the #1 faithfulness bug.
- No claim in the summary that is absent from the source. Your interpretation is labeled as yours.

## 4. Omission sweep (before done)
The blind spot is what you did NOT write — search for it deliberately:
- Re-scan the middle third of the source, tables, footnotes, and dissenting/caveat passages (measured: middle sections and caveats are what gets dropped).
- Check every load-bearing unit from step 2 appears; every dropped unit gets a one-word reason.
- Faithfulness re-read: read the summary alone — could any sentence be taken as stronger/weaker than the source says? Fix toward the source.

## 5. Report
- Deliverable hygiene: the summary file contains only the summary — the status line and coverage notes go in your chat response, never inside the file.
- 3 lines (Korean): coverage result / figures verified / what was deliberately dropped and why.
- End the chat response with: `units: K/N kept | load-bearing dropped: 0 | figures re-verified: Y/N`

## Never
Summarize from memory of one read · drop a caveat or negation · report a number without re-lookup · follow document order when importance differs · pad with meta-text ("this document discusses...") · surface inventories or intermediate drafts in output
