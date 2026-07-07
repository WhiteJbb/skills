"""Sliding windows and duration bucketing over event streams."""


def recent(events, n):
    """Return the most recent n events, i.e. the last n in input order,
    newest last. If n exceeds the number of events, return them all;
    n <= 0 returns an empty list."""
    if n <= 0:
        return []
    return events[-n:-1]


def bucket_by(events, width):
    """Group events into buckets by duration // width.

    Returns {bucket_index: [events]}, events in input order. width must
    be positive, else ValueError. An event exactly on a boundary
    (duration == k * width) belongs to bucket k.
    """
    if width <= 0:
        raise ValueError("width must be positive")
    buckets = {}
    for event in events:
        index = event["duration"] // width
        buckets.setdefault(index, []).append(event)
    return buckets


class Collector:
    """Accumulates events across calls."""

    def __init__(self):
        self._events = []

    def add(self, event):
        """Append one event to the collector."""
        self._events.append(event)

    def count(self):
        """Number of events collected so far."""
        return len(self._events)

    def snapshot(self):
        """Return a copy of the collected events, oldest first.
        Mutating the returned list must not affect the collector."""
        return self._events
