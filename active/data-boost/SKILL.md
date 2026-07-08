---
name: data-boost
description: Data-analysis harness — profile the data with executed code BEFORE any analysis, define metrics precisely up front, every reported number printed by code you ran, row-count sanity checks on every join/filter, pattern claims require a computed check. Use at the START of any data-analysis/EDA/metrics/dataset task when running on Sonnet or Opus. Skip questions with no data at hand.
---

# Data Boost

Blocks the 4 causes of wrong analysis: unprofiled data, mental arithmetic, unvalidated transforms, generic insights. Every number the user reads must have been printed by code you executed.

## Language
Chat responses in Korean. Deliverable artifacts (findings/report files) follow the request's language — default to the dataset/source language (measured: a Korean findings.md against an English dataset and brief reads as a mismatch). Code and column names follow the dataset's convention.

## 1. Question contract
- One line: the decision this analysis serves.
- Define each metric precisely BEFORE computing: numerator, denominator, filters, time window — "conversion rate" has five definitions; pick one in writing.

## 2. Profile first (executed, never assumed)
- Run and read: shape, dtypes, null counts per column, duplicate rows/keys, min/max ranges, cardinality of categoricals, time coverage.
- Nulls, dupes, and encoding surprises found here change everything downstream — profiling after analyzing is re-analyzing.
- One line per anomaly; decide explicitly: fix / exclude (with count) / keep (with reason).

## 3. Analyze with checked steps
- One transform → one sanity check → next. Never batch-verify.
- Row counts before/after EVERY join and filter — a silently exploding or shrinking join is the #1 wrong-number source. Totals reconcile against raw data; spot-check 3 actual rows after any nontrivial derivation.
- Every number destined for the conclusion is printed by executed code. No mental math, no extrapolating from a glanced sample, no reusing a figure computed on stale data.

## 4. Pattern claims require a computed check
- "Increasing trend" → compute the change and magnitude over defined periods. "A differs from B" → effect size AND group sizes (n) — a 2x lift on n=7 is noise until shown otherwise.
- Correlation ≠ cause: name the confounder candidates or don't claim cause. Simpson's check on any group comparison: does the direction hold within major segments?
- Insight bar: non-obvious + quantified + actionable. "Sales show an upward trend" fails all three.

## 5. Done gate
- Re-run the full script/notebook top-to-bottom once — stale-state results from out-of-order execution are the measured classic.
- Every figure in the report traces to an executed cell/line. Charts follow dataviz rules.
- Deliverable hygiene: the findings file contains only the analysis its reader needs — the status line below goes in your chat response, never inside the file.
- End the chat response with: `profiled: Y | joins/filters count-checked: K/K | conclusion figures from executed code: N/N | full re-run: pass`

## Never
Analyze before profiling · report a number you didn't print · trust a join without row counts · claim cause from correlation · call a trend without magnitude · ship without a top-to-bottom re-run
