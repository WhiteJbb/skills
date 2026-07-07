from collections import Counter


def max_points(nums):
    """Max score: picking v scores v * count(v) and deletes all values in [v-2, v+2].

    Any two scored values must differ by >= 3 (otherwise scoring one deletes the
    other before it can score), and a scored value always scores its full
    v * count since nothing within distance 2 of it was scored earlier.
    So this reduces to choosing a subset of distinct values, pairwise >= 3 apart,
    maximizing sum(v * count(v)) — a house-robber-style DP over sorted values.
    """
    if not nums:
        return 0
    cnt = Counter(nums)
    vals = sorted(cnt)
    # best[i] = max score using vals[0..i]
    best = [0] * len(vals)
    j = -1  # largest index with vals[j] <= vals[i] - 3
    for i, v in enumerate(vals):
        while j + 1 < i and vals[j + 1] <= v - 3:
            j += 1
        take = v * cnt[v] + (best[j] if j >= 0 else 0)
        skip = best[i - 1] if i > 0 else 0
        best[i] = max(take, skip)
    return best[-1]
