"""Grader for the rangestats implementation task.

Splits the seeded difficulty into two classes and prints per-class scores:

- CRASH class: functions that raise on an edge input (empty list / zero
  divisor) if the guard is omitted. A model that runs each function on
  empty/zero inputs (input-partition coverage) SEES the crash and fixes
  it — this is what a mechanical sweep catches.
- LOGIC class: functions that return a plausible-but-wrong value on
  ordinary input if a subtle rule is misread (even-length median,
  tie direction, percentile index). No crash on any input, so a sweep
  gives no signal; only checking output against the stated rule catches
  it. This is the ceiling of the judgment->mechanism lever.

Exit 0 only when both classes are fully correct and the happy-path
sanity checks hold.
"""

import os
import sys

sys.path.insert(0, os.getcwd())
from rangestats import mean, median, mode, pct, safe_div, first_or

CRASH = []
LOGIC = []
SANITY = []


def rec(bucket, label, got, want):
    ok = got == want
    bucket.append((label, ok))
    print("%s: %s%s" % (label, "PASS" if ok else "FAIL",
                        "" if ok else " (got %r want %r)" % (got, want)))


def rec_call(bucket, label, fn):
    try:
        got = fn()
        bucket.append((label, True))
        print("%s: PASS" % label)
    except Exception as exc:
        bucket.append((label, False))
        print("%s: FAIL (%s: %s)" % (label, type(exc).__name__, exc))


def run():
    # --- CRASH class: edge inputs that throw if unguarded ---
    rec_call(CRASH, "CRASH mean-empty", lambda: _eq(mean([]), 0.0))
    rec_call(CRASH, "CRASH safediv-zero", lambda: _is(safe_div(1.0, 0), None))
    rec_call(CRASH, "CRASH firstor-empty", lambda: _eq(first_or([], "x"), "x"))

    # --- LOGIC class: wrong value on ordinary input if a rule is misread ---
    rec(LOGIC, "LOGIC median-even", median([1, 2, 3, 4]), 2.5)       # avg of 2 and 3
    rec(LOGIC, "LOGIC mode-tie", mode([2, 2, 1, 1]), 1)              # tie -> smallest (insertion order gives 2)
    rec(LOGIC, "LOGIC pct-index", pct([10, 20, 30, 40, 50], 40), 20)  # ceil(.4*5)-1=1 -> 20

    # --- SANITY: happy path must still hold (guards against trivial breakage) ---
    rec(SANITY, "SANITY mean", mean([2, 4]), 3.0)
    rec(SANITY, "SANITY median-odd", median([3, 1, 2]), 2.0)
    rec(SANITY, "SANITY mode-clear", mode([4, 4, 4, 2]), 4)
    rec(SANITY, "SANITY pct-max", pct([10, 20, 30, 40, 50], 100), 50)
    rec(SANITY, "SANITY safediv", safe_div(9.0, 2), 4.5)
    rec(SANITY, "SANITY firstor", first_or([7, 8], "x"), 7)

    c = sum(1 for _, ok in CRASH if ok)
    l = sum(1 for _, ok in LOGIC if ok)
    s_ok = all(ok for _, ok in SANITY)
    print("CRASH %d/3 | LOGIC %d/3 | sanity %s" % (c, l, "PASS" if s_ok else "FAIL"))
    if c == 3 and l == 3 and s_ok:
        print("HIDDEN OK")
        return 0
    return 1


def _eq(got, want):
    assert got == want, "got %r want %r" % (got, want)


def _is(got, want):
    assert got is want, "got %r want %r" % (got, want)


if __name__ == "__main__":
    try:
        code = run()
    except Exception as exc:
        print("HIDDEN FAIL (%s: %s)" % (type(exc).__name__, exc))
        code = 1
    sys.exit(code)
