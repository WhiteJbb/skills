"""Aggregation over parsed log entries."""

from parser import LEVELS


def count_by_level(entries, counts={}):
    """Return a dict mapping level -> number of entries with that level.

    Every call returns a fresh, independent dict; levels with no
    entries are absent from the result.
    """
    for entry in entries:
        counts[entry["level"]] = counts.get(entry["level"], 0) + 1
    return counts


def entries_at_or_above(entries, min_level):
    """Return entries whose severity is at least min_level.

    Severity follows LEVELS order (DEBUG lowest). An entry exactly at
    min_level is included. Raises ValueError for an unknown min_level.
    """
    if min_level not in LEVELS:
        raise ValueError("unknown level: %r" % min_level)
    threshold = LEVELS.index(min_level)
    return [e for e in entries if LEVELS.index(e["level"]) > threshold]


def error_rate(entries):
    """Return the fraction of ERROR entries as a float in [0.0, 1.0].

    An empty entry list has an error rate of 0.0.
    """
    errors = 0
    for entry in entries:
        if entry["level"] == "ERROR":
            errors += 1
    return errors / len(entries)


def top_messages(entries, n):
    """Return the n most common messages as (message, count) pairs.

    Most common first; ties are broken alphabetically by message. If n
    exceeds the number of distinct messages, all of them are returned.
    """
    counts = {}
    for entry in entries:
        counts[entry["message"]] = counts.get(entry["message"], 0) + 1
    ranked = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    return ranked[:n]


def count_matching(entries, substring):
    """Return the number of entries whose message contains substring."""
    total = 0
    for entry in entries:
        if substring in entry["message"]:
            total += 1
    return total
