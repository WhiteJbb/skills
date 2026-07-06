---
name: opus-boost
description: Token-efficient quality harness enforcing understand → plan → small-step implementation → adversarial self-review → end-to-end verification. Use at the START of any nontrivial coding task (implementation, debugging, refactoring, multi-file change) when running on Opus. If on Sonnet/Haiku use sonnet-boost instead. Skip for trivial one-liners or pure Q&A.
---

# Opus Boost

Blocks the 4 causes of quality gap: rushed start, skipped verification, first-idea lock-in, unfinished ending. Follow in order. No skipping.

## Language
All user-facing responses in Korean. Code, identifiers, comments, commit messages follow repo convention (usually English).

## Principles
- Verify with tools, not memory. Confirm any assumed API/function/config exists via Grep/Read before using it.
- Only what you executed and observed counts as done.
- State uncertainty explicitly. Never fill gaps with plausible guesses.

## Token discipline (applies throughout)
- Read only the needed line ranges. Never re-read files already in context.
- Exploration touching 4+ files or unfamiliar structure: delegate to Explore subagent(s), parallel when independent; take back a structured map (path → role → key symbols), never raw file dumps.
- No long code quotes in responses — reference file:line.
- One line per plan/checklist item. No prose narration between steps.
- Verify with the cheapest check that catches the mistake (typecheck → targeted test → full suite).

## 1. Start
- Restate the requirement in one sentence. If ambiguous, state the chosen interpretation.
- Before editing, read: target code + all call sites (Grep) + one similar existing implementation.

## 2. Plan (required for 2+ files or complex logic)
- 3-7 steps, one line each, with a done-criterion per step.
- If 2+ approaches exist: one-line tradeoff each, then a one-sentence reason for the choice. Never lock onto the first idea.
- Wide solution space AND costly to reverse (architecture, schema, public API): spawn 3 parallel subagents with forced-diverse angles (simplest-correct / risk-first / performance-first), each returning a ≤10-line plan; judge against the requirements, adopt the winner, graft the best ideas from the rest. Otherwise the tradeoff line above suffices.
- List applicable edge cases first: empty/null/boundary/failure path/concurrency/encoding/timezone.

## 3. Implement
- One step → immediate cheapest verification → next. Never batch-verify.
- On error: read the full message, find the root cause. No symptom patching (try/catch wrap, extra condition).
- Search for existing utils before writing new ones. Follow existing style and patterns.

## 4. Self-review (mandatory before claiming done)
Re-read the whole diff as if reviewing a stranger's PR; hunt for inputs that break it:
- [ ] off-by-one, empty collection, boundary values
- [ ] null/undefined inflow paths
- [ ] resource leaks on error paths, swallowed exceptions
- [ ] every call site of any changed signature (confirm via Grep)
- [ ] leftovers depending on deleted/changed code
Fix and repeat until clean.

Then, for multi-file or risky diffs (public API, data handling, concurrency, security) — fresh-context adversarial verify:
- Spawn 2-3 parallel subagents, each given ONLY the requirement + diff (none of your reasoning or conclusions) and one distinct lens: correctness / edge-cases / security.
- Instruct each to REFUTE the claim "this diff is correct and complete". The context that wrote a bug cannot see it; fresh eyes can.
- Fix confirmed findings and re-verify; dismiss false positives with a one-line reason each.

## 5. Finish
- Run tests; if none, execute the changed path once and observe.
- Report failures/skips as-is.
- Final report, 3 lines (in Korean): what was done / what was executed and verified / what remains uncertain.

## Audit tasks (only when the task itself is find-all-bugs / review-a-module)
- Parallel finder subagents with distinct lenses: dataflow, error paths, concurrency, boundaries.
- Loop until dry: repeat with fresh finders until 2 consecutive rounds add nothing new; dedup against ALL findings seen so far, not just confirmed ones.
- One fresh-context skeptic per finding tries to refute it; report only survivors, with file:line.

## Never
Assert without checking · claim done without executing · paste code you don't understand · retry without reading the error · refactor beyond the request
