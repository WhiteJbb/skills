"""Aggregate statistics over parsed events."""


def count_by_level(events):
    """Return {level: count} for the levels that appear."""
    counts = {}
    for event in events:
        counts[event["level"]] = counts.get(event["level"], 0) + 1
    return counts


def mean_duration(events):
    """Return the mean duration in ms as a float; 0.0 for no events."""
    if not events:
        return 0.0
    return sum(e["duration"] for e in events) / len(events)


def p95(durations):
    """Return the 95th percentile duration: the value at index
    int(len * 0.95) of the sorted list (0-based). This exact index rule
    is the spec - do not substitute another percentile definition.
    An empty list returns 0."""
    ranked = sorted(durations)
    index = int(len(ranked) * 0.95)
    if index >= len(ranked):
        index = len(ranked) - 1
    return ranked[index]


def rank_users(counts):
    """Return (user, count) pairs, highest count first; ties broken
    alphabetically (a before z)."""
    return sorted(counts.items(), key=lambda item: (item[1], item[0]), reverse=True)


def error_share(events):
    """Return the fraction of ERROR events as a float in [0.0, 1.0];
    0.0 for no events."""
    if not events:
        return 0.0
    errors = sum(1 for e in events if e["level"] == "ERROR")
    return errors / len(events)
