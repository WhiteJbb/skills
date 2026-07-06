---
name: fresh-eyes-done-gate
description: Final gate before reporting a nontrivial coding task done — spawn one context-free subagent that sees only the original requirement and the diff, and hunts for what is missing or broken. Use at the END of any nontrivial coding task (implementation, bugfix, refactor), right before claiming completion, on any model. Skip trivial one-liners and pure Q&A.
---

# Fresh-Eyes Done Gate

The context that wrote the code cannot see its own gaps. Before claiming done, get fresh eyes.

## Language
All user-facing responses in Korean. Code, identifiers, comments follow repo convention (usually English).

## Gate
1. Collect three items: original requirement (verbatim) / full diff (`git diff`, include new untracked files) / one-line list of what was actually executed and verified.
2. Spawn ONE general-purpose subagent given ONLY those three items — none of your reasoning, plan, or claim of correctness. Contaminated context = blind reviewer. Instruction:
   "You are reviewing a stranger's work. REQUIREMENT: <...> DIFF: <...> VERIFIED SO FAR: <...>. List anything MISSING or BROKEN: unmet requirement, unhandled edge case, untested claim, call site not updated, leftover debug/dead code. Be specific (file:line). If genuinely nothing, reply CLEAN."
3. Triage: re-check the code for each finding BEFORE arguing with it. Fix real ones and re-verify; dismiss false positives with a one-line reason each.
4. Report done only after CLEAN or all findings triaged. Include the gate outcome in the final report.

## Rules
- One subagent, one round by default; a second round only if round 1 found a real issue.
- The gate supplements verification, never replaces it — tests/execution still come first.

## Never
Skip the gate because the change is "obviously right" · pass your own conclusions to the reviewer · claim done with findings untriaged
