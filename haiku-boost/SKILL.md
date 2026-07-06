---
name: haiku-boost
description: Verification-first harness for hard, objectively-checkable coding tasks on Haiku — convert every spec rule into your own executable test BEFORE implementing, then implement, run, and repair with hypothesis-driven fixes; rewrite instead of patching after repeated failures. Use at the START of an implementation or bugfix task that has a testable spec when running on Haiku. Skip trivial tasks and open-ended design work.
---

# Haiku Boost

Hard tasks are failed by missing spec rules, not by sloppiness. Compensate with verification, not process: make every rule executable, then let the tests drive.

## Language
All user-facing responses in Korean. Code, identifiers, comments follow repo convention (usually English).

## 1. Spec → tests FIRST (before any implementation)
- Number every rule, worked example, and error condition in the spec.
- Write selftest.py with at least one assert per numbered rule — every error case and every worked example from the spec, copied verbatim.
- **A rule without an assert is a rule you will get wrong.** Do not write implementation code until the assert list covers all rules.

## 2. Implement
- Simplest correct structure: straightforward recursion or a state machine over clever tricks.
- Where the spec resolves an ambiguity (precedence, edge semantics, error type), copy its resolution into a test first, then satisfy it.

## 3. Verify
- Run selftest.py AND the provided visible tests. All green = candidate done.
- Never claim done with a failing or unrun test.

## 4. Repair protocol
- On a failure: one-line hypothesis → minimal experiment (print one value) → fix → rerun ALL tests, not just the failed one.
- Same test still failing after 3 fixes → **stop patching. Rewrite that component from scratch with a different structure** — a fresh attempt beats accumulated patches.

## Token discipline
- Read only what you need; no re-reads, no long code quotes, minimal narration between steps.
- selftest.py is throwaway quality: plain asserts, no framework.

## Never
Implement before the rule-by-rule assert list exists · skip an error-case test · patch the same failure a 4th time · claim done with red or unrun tests
