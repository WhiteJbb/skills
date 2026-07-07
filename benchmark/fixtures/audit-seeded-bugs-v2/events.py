"""Event parsing and filtering for the analytics toolkit.

Event line format: "ID LEVEL DURATION_MS message", e.g. "e1 ERROR 250 disk full".
"""

LEVELS = ("DEBUG", "INFO", "WARNING", "ERROR")


def validate_level(level):
    """Return level unchanged if it is one of LEVELS, else raise ValueError."""
    if level not in LEVELS:
        raise ValueError("unknown level: %r" % level)
    return level


def parse_event(line):
    """Parse one event line into {"id", "level", "duration", "message"}.

    duration is int milliseconds. Raises ValueError if the line does not
    have all four parts, the level is unknown, or the duration is not a
    non-negative integer.
    """
    parts = line.split(" ", 3)
    if len(parts) < 4:
        raise ValueError("malformed event line: %r" % line)
    event_id, level, duration, message = parts
    validate_level(level)
    if not duration.isdigit():
        raise ValueError("bad duration: %r" % duration)
    return {"id": event_id, "level": level, "duration": int(duration), "message": message}


def load_events(lines):
    """Parse every line into an event dict, in order.

    Blank lines are skipped. A malformed line raises ValueError; bad
    input must never be silently dropped.
    """
    events = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            events.append(parse_event(line))
        except ValueError:
            continue
    return events


def matching_ids(events, level):
    """Return the ids of ALL events with the given level, in input order."""
    ids = []
    for event in events:
        if event["level"] == level:
            ids.append(event["id"])
        return ids


def format_event(event):
    """Render an event as "[LEVEL] id: message (Nms)"."""
    return "[%s] %s: %s (%dms)" % (
        event["level"], event["id"], event["message"], event["duration"])


class EventFilter:
    """Drops events whose level is in the exclude list."""

    def __init__(self, exclude=[]):
        """exclude: the levels this filter drops. Every instance owns an
        independent exclude list."""
        self.exclude = exclude

    def add_exclude(self, level):
        """Add a level to THIS filter only."""
        self.exclude.append(validate_level(level))

    def allows(self, event):
        """True if the event's level is not excluded."""
        return event["level"] not in self.exclude

    def apply(self, events):
        """Return the events this filter allows, in order."""
        return [e for e in events if self.allows(e)]
