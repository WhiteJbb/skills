---
name: sonnet-boost
description: Token-efficient strict harness for fast models (Sonnet, Haiku) — requirement contract, verify-before-use, one-change-one-check, requirements re-check before done. Use at the START of any nontrivial coding task (implementation, debugging, refactoring, multi-file change) when running on Sonnet or Haiku. Skip for trivial one-liners or pure Q&A.
---

# Sonnet Boost

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
- Exploration touching 4+ files or unfamiliar structure: delegate to an Explore subagent; take back a structured map (path → role → key symbols), never raw file dumps.
- No long code quotes in responses — reference file:line.
- One line per list/plan item. Minimal narration between steps.
- Verify with the cheapest check that catches the mistake (typecheck → targeted test → full suite).

## 1. Start gate — requirement contract
1. Extract explicit requirements as a numbered list, one line each. This list is the contract.
2. Add a one-line verification method per item (e.g., 3. empty input → call directly with []).
3. State the chosen interpretation for anything ambiguous; ask first only if it materially changes the outcome.
Ideas not on the list do not get done, even if they come up mid-task.

## 2. Investigate — 3 checks before any edit
- Target code body (needed range only)
- All call sites via Grep — never assume it is only used here
- One similar existing implementation — copy its style and error handling

## 3. Implement
- Simplest working approach. Abstraction/generalization only when requested.
- For complex logic: write 2-3 input→output examples first, trace the code against them, then execute to confirm.

## 4. Error protocol
- Read the message from first line to last. No retry without reading.
- **Two failures with the same approach → stop.** Before attempt 3: write a one-line hypothesis + run a minimal experiment (print the value, run in isolation). No hypothesis-free code shuffling.
- No symptom patching (try/catch wrap, extra condition). Answer why this value appeared here, then fix.

## 5. Done gate — contract check
1. Return to the step-1 list; check each item against actual executed results. Mark unverified items UNVERIFIED — never silently skip.
2. Re-read the diff: all call sites of changed signatures updated? debug prints or dead code left? out-of-scope changes mixed in?
3. Run tests; if none, execute the changed path once.
4. Multi-file or risky diff (public API, data handling, concurrency): spawn ONE fresh-context subagent given ONLY the contract + diff (none of your reasoning), instructed to refute "this diff is correct and complete". Fix real findings and re-verify; dismiss false positives with a one-line reason.
5. Final report, 3 lines (in Korean): contract check results / what was executed and verified / what is unverified or uncertain. Never hide failures or skips.

## Never
Assume an API exists · retry without reading the error · repeat 3+ times without a hypothesis · edit beyond the request · claim done without executing · omit unverified items from the report
