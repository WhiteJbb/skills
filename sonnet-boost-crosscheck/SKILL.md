---
name: sonnet-boost-crosscheck
description: Reasoning-amplified variant of sonnet-boost — for algorithmic/non-obvious-correctness tasks, mandates writing a SECOND independent brute-force reference and differential-testing the two on a broad random sweep before claiming done. Use at the START of any nontrivial coding task on Sonnet or Haiku. Skip trivial one-liners or pure Q&A.
---

# Sonnet Boost (cross-check variant)

Blocks the 5 causes of quality gap: requirement drift, API hallucination, thrash loops, out-of-scope edits, unverified completion. These are mandates, not judgment calls.

## Language
All user-facing responses in Korean. Code, identifiers, comments, commit messages follow repo convention (usually English).

## Hard rules
- **Verify before use**: confirm every import/function/config key/CLI flag exists via Grep/Read before writing it. Copy signatures verbatim from source. Never from memory.
- **One change, one check**: edit one file → cheapest verification → next. Never batch-verify.
- **Scope lock**: no refactoring/cleanup/improvement beyond the request. Report discovered issues at the end; do not fix them.
- **Never write done for anything not executed.**

## Token discipline (applies throughout)
- Read only the needed line ranges. Never re-read files already in context.
- No long code quotes in responses — reference file:line. One line per list/plan item.
- Verify with the cheapest check that catches the mistake.

## 1. Start gate — requirement contract
1. Extract explicit requirements as a numbered list, one line each. This list is the contract.
2. Add a one-line verification method per item.
3. State the chosen interpretation for anything ambiguous.
4. A reported bug/rule names an input CLASS, not just its literal examples.
Ideas not on the list do not get done.

## 2. Investigate — 3 checks before any edit
- Target code body (needed range only)
- All call sites via Grep
- One similar existing implementation — copy its style and error handling

## 3. Implement
- Smallest change a maintainer would accept; fix at the root cause locally. Abstraction only when requested.
- For every rule and error case: write an input→output example (include empty/boundary/special-char inputs) and execute it to confirm.

## 3b. Independent cross-check (MANDATORY when correctness is non-obvious)
Trigger — a COUNTABLE condition, not a judgment: the task computes a value by a non-trivial rule and any of these words fit — recurrence, dynamic programming, greedy, combinatorial count, optimization / "maximum" / "minimum", parsing with precedence, graph/path, game. Your clever solution PLUS your own hand-picked tests share ONE blind spot: if you reasoned the rule wrong, you will also write tests that confirm the wrong answer. A second, independent derivation does not share that blind spot.
- Write a SECOND implementation that is obviously correct by brute force — exhaustive search / naive simulation of the literal rules, ignoring all efficiency. Derive it from the PROBLEM STATEMENT, not from your fast solution.
- Run BOTH on a broad sweep of randomly generated small inputs (dozens to hundreds), plus boundary inputs (empty, single, all-equal, values exactly at the rule's threshold). Compare outputs exactly.
- ANY disagreement is a real bug in one of the two. Find which is wrong (re-read the statement), fix it, re-run the sweep. Do NOT stop, and do NOT trust the fast solution over the brute force, until they agree across the whole sweep.
- Keep the brute force in a scratch file; the deliverable is the efficient solution, now cross-checked.

## 4. Error protocol
- Read the message first line to last. Two failures with the same approach → stop; write a one-line hypothesis + a minimal experiment before attempt 3. No symptom patching.

## 5. Done gate — contract check
1. Return to the step-1 list; check each item against actual executed results. Mark unverified items UNVERIFIED.
2. Re-read the diff: call sites updated? debug prints / dead code left? out-of-scope changes?
3. Run tests; if none, execute the changed path once.
4. Final report, 3 lines (in Korean): contract check / what was executed and verified / what is unverified. End with the status line `cross-check: done (N random inputs, agreed) | not applicable | rules proven: K/M`.

## Never
Assume an API exists · retry without reading the error · ship an algorithmic solution checked only with hand-picked cases · trust a clever solution over a brute-force reference when they disagree · claim done without executing
