---
name: code-review-boost
description: Adversarial code-review harness — read call sites before commenting, sweep the diff with 6 fixed defect lenses one at a time, confirm each finding with a concrete triggering input, rank by severity, loop until two clean rounds. Use at the START of any code-review/audit/find-bugs task when running on Sonnet or Opus. Skip trivial single-line diffs.
---

# Code Review Boost

Blocks the 4 causes of shallow review: commenting without context, style-only findings, unconfirmed accusations, stopping at first findings. A review's value = confirmed defects the author didn't see.

## Language
User-facing responses in Korean. PR/inline comments follow repo convention (usually English).

## 1. Context before comments (mandatory)
- Read the full diff, then for every changed function: its call sites (Grep) and the surrounding code the diff doesn't show. Diff-only review misses call-site breakage — the highest-severity common bug.
- One line: what this change claims to do. Review against that claim, not against taste.

## 2. Lens sweep — each lens is a SEPARATE pass over the diff
One combined pass finds the union of nothing. Run all applicable, one at a time:
1. Dataflow: null/undefined inflow, uninitialized state, stale reads
2. Boundaries: off-by-one, empty collection, first/last element, zero/negative
3. Error paths: swallowed exceptions, partial failure, missing cleanup on throw
4. Contract: changed signature/behavior vs EVERY call site; docs vs implementation
5. Concurrency/state: shared mutation, ordering assumptions, reentrancy
6. Security: injection, unvalidated input, secrets, path traversal (when surface exists)
Large diff (5+ files): parallel finder subagents, one lens each; dedup against ALL findings seen so far, not just confirmed ones.

## 3. Confirm before reporting
- For each candidate finding, construct the concrete input/sequence that triggers it; trace or run it. Label CONFIRMED (traced/ran) or PLAUSIBLE (could not trace) — never assert a maybe as a bug.
- Each finding: file:line + failure scenario (input → wrong outcome) + minimal fix direction. No "consider improving…" filler.

## 4. Loop until dry (audits / thorough reviews)
- Repeat the sweep with fresh eyes until 2 consecutive rounds add nothing new. "I found them all" after one round IS the blind spot (measured: solo audits stop one bug short).

## 5. Report
- Findings ranked most-severe first; bugs strictly separated from nits; nits only if asked.
- Praise only what is specifically good, one line max. No summary-of-the-diff filler.
- Deliverable hygiene: a review file/PR comment contains only findings — no lens bookkeeping or process notes inside it. The status line below goes in your chat response.
- End the chat response with: `lenses: K/6 run | findings: C confirmed / P plausible | rounds until dry: R`

## Never
Comment without reading call sites · report style when asked for bugs · assert an unconfirmed finding as fact · stop after one round on an audit · merge all lenses into one pass · pad by restating the diff
