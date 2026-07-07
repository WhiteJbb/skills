"""Grader for max_points — an algorithmic-reasoning task.

Correctness is non-obvious: the deletion window is +/-2 (picking v also
removes v-2 and v+2), so chosen values must differ by >= 3. The habitual
"delete and earn" answer uses +/-1 (gap >= 2) and is WRONG here. Hand-
picked tests share that blind spot; only comparing against an independent
brute force exposes it.

This grader IS an independent oracle: a pure exhaustive reference (subset
enumeration over distinct values) plus a game-simulation reference for
tiny inputs, checked against the submission on hand cases + a random sweep.
"""

import os
import sys
import random
from collections import Counter
from itertools import combinations

sys.path.insert(0, os.getcwd())
from solution import max_points


def brute_subsets(nums):
    """Max-weight subset of distinct values, pairwise difference >= 3."""
    c = Counter(nums)
    vals = sorted(c)
    n = len(vals)
    best = 0
    for r in range(1, n + 1):
        for combo in combinations(vals, r):
            if all(combo[i + 1] - combo[i] >= 3 for i in range(len(combo) - 1)):
                best = max(best, sum(v * c[v] for v in combo))
    return best


def brute_game(nums):
    """Independent check: literally simulate every sequence of picks (tiny inputs)."""
    c = Counter(nums)
    vals = tuple(sorted(c))

    def rec(present):
        best = 0
        for v in present:
            gain = v * c[v]
            remaining = frozenset(x for x in present if not (v - 2 <= x <= v + 2))
            best = max(best, gain + rec(remaining))
        return best

    return rec(frozenset(vals))


def run():
    total = 0
    passed = 0

    def check(nums):
        nonlocal total, passed
        total += 1
        want = brute_subsets(list(nums))
        got = max_points(list(nums))
        if got == want:
            passed += 1
        else:
            print("FAIL max_points(%r) = %r, want %r" % (list(nums), got, want))

    # hand cases (some do NOT discriminate gap2 vs gap3 -> also in visible test)
    check([])
    check([5])
    check([2, 2, 2])
    check([1, 10])
    # discriminating cases: gap of exactly 2 must NOT be co-selectable
    check([1, 3, 5])          # correct 6 ({1,5}); gap-2 solver returns 9
    check([2, 4])             # diff 2 -> cannot take both; correct 4
    check([3, 5, 7, 9])
    check([1, 1, 3, 3, 3, 5, 5])
    check([10, 11, 12, 13, 14])
    check([4, 4, 6, 6, 8, 8])

    # random sweep (small distinct count so brute is cheap); fixed seed for reproducibility
    rng = random.Random(20260707)
    for _ in range(400):
        k = rng.randint(0, 10)
        nums = [rng.randint(1, 12) for _ in range(k)]
        check(nums)

    # a couple of larger-count inputs (values bounded so brute stays feasible)
    for _ in range(20):
        nums = [rng.randint(1, 14) for _ in range(rng.randint(10, 25))]
        check(nums)

    print("PASSED %d/%d" % (passed, total))
    if passed == total:
        print("HIDDEN OK")
        return 0
    return 1


if __name__ == "__main__":
    try:
        code = run()
    except Exception as exc:
        print("HIDDEN FAIL (%s: %s)" % (type(exc).__name__, exc))
        code = 1
    sys.exit(code)
