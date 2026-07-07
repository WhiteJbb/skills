---
name: sonnet-boost
description: Token-efficient strict harness for fast models (Sonnet, Haiku) — requirement contract, verify-before-use, one-change-one-check, prove every rule with an executed example, requirements re-check before done. Use at the START of any nontrivial coding task (implementation, debugging, refactoring, multi-file change) when running on Sonnet or Haiku. Skip for trivial one-liners or pure Q&A.
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
4. A reported bug/rule names an input CLASS, not just its literal examples: the contract item covers the class (special chars, empty, boundary), and "the rest is out of scope" is a rule violation, not a judgment call.
Ideas not on the list do not get done, even if they come up mid-task.

## 2. Investigate — 3 checks before any edit
- Target code body (needed range only)
- All call sites via Grep — never assume it is only used here
- One similar existing implementation — copy its style and error handling

## 3. Implement
- Smallest change a maintainer would accept: fix at the root cause locally; no new mechanism where a local edit matching the codebase's existing pattern works (find one instance first). Abstraction/generalization only when requested.
- For every rule and error case: write an input→output example — include adversarial inputs (empty, boundary, special chars), not just the spec's happy example — then execute it to confirm. A rule with no executed example is a rule you have probably gotten wrong.

## 4. Error protocol
- Read the message from first line to last. No retry without reading.
- **Two failures with the same approach → stop.** Before attempt 3: write a one-line hypothesis + run a minimal experiment (print the value, run in isolation). No hypothesis-free code shuffling.
- No symptom patching (try/catch wrap, extra condition). Answer why this value appeared here, then fix.

## 5. Done gate — contract check
1. Return to the step-1 list; check each item against actual executed results. Mark unverified items UNVERIFIED — never silently skip.
2. Re-read the diff: all call sites of changed signatures updated? debug prints or dead code left? out-of-scope changes mixed in?
3. Run tests; if none, execute the changed path once.
4. Spawn ONE fresh-context probe on a COUNTABLE condition — never on your judgment of "impact"/"scope"/"done-ness" (that judgment is the blind spot being checked; you WILL rationalize a public-API change as "local"). Spawn if ANY hold: (a) a public/exported signature or behavior changed, (b) 2+ source files touched, (c) a contract item lacks a passing executed example. Give the subagent ONLY the contract + diff (none of your reasoning), told: "find one input that makes this violate the contract — the reported bug is a whole input class, not just its literal examples." A targeted probe, not an audit. A still-broken input in the reported bug's class is IN scope: reproduce with a run and fix. Dismiss a genuine false positive in one line.
5. Final report, 3 lines (in Korean): contract check results / what was executed and verified / what is unverified or uncertain. Never hide failures or skips. End with this exact status line, every field filled with the real value — not a judgment:
`files changed: N | public behavior changed: Y/N | find-all-bugs task: Y/N | probe: fired|not needed | rules proven: K/M`
`not needed` (no fresh-context probe) is permitted ONLY when N≤1 AND public=N; a find-all-bugs task instead requires the Audit-section self-test sweep, run regardless. You must write the true N. (Measured: forcing the count makes Sonnet write "files changed: 3" honestly — but it will still skip a subagent even after admitting every condition is true, which is exactly why audit completeness uses the self-test sweep, a mechanism it actually follows.)

## Audit / find-all-bugs tasks
Completeness cannot be self-assessed — "I found them all" IS the blind spot (measured: solo Sonnet audits stop one bug short, and it will NOT spawn a finder here even when instructed). So secure completeness with the mechanism you DO follow — an executed self-test sweep, not a subagent:
- After fixing, run EVERY function and method in the module on adversarial inputs — empty collection, single element, zero, boundary, unexpected type — INCLUDING the ones you never flagged as buggy.
- The bug you will miss lives in a function you didn't suspect, so didn't test (measured: the missed bug was an empty-input crash in an unflagged function — one `f([])` call would have caught it).
- Completeness = executed input coverage of ALL functions, not confidence in the bugs you found. Do not report done until every function has been run on an empty/boundary input.

## Never
Assume an API exists · retry without reading the error · repeat 3+ times without a hypothesis · edit beyond the request · claim done without executing · omit unverified items from the report · rationalize a public-API or 2+-file change as "local" to skip the probe
