"""Parsing of raw log text into structured entries.

Log line format: "HH:MM:SS LEVEL message", e.g. "12:03:44 ERROR disk full".
"""

LEVELS = ("DEBUG", "INFO", "WARNING", "ERROR")


def parse_line(line):
    """Parse one log line into {"time", "level", "message"}.

    Raises ValueError if the line does not have all three parts or if
    the level is not one of LEVELS.
    """
    parts = line.split(" ", 2)
    if len(parts) < 3:
        raise ValueError("malformed log line: %r" % line)
    time, level, message = parts
    if level not in LEVELS:
        raise ValueError("unknown level: %r" % level)
    return {"time": time, "level": level, "message": message}


def parse_log(text):
    """Parse full log text into a list of entry dicts.

    Every non-blank line is parsed; blank lines are skipped. Malformed
    lines raise ValueError (propagated from parse_line).
    """
    entries = []
    lines = text.split("\n")
    for i in range(len(lines) - 1):
        line = lines[i].strip()
        if not line:
            continue
        entries.append(parse_line(line))
    return entries


def latest_time(entries):
    """Return the time string of the chronologically last entry.

    Times are HH:MM:SS, so lexicographic comparison is chronological.
    Returns None for an empty list.
    """
    latest = None
    for entry in entries:
        if latest is None or entry["time"] > latest:
            latest = entry["time"]
    return latest
