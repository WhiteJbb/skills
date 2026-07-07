"""Rendering of analysis results."""

from aggregator import count_by_level, error_rate
from parser import LEVELS, parse_log


def render_counts(counts):
    """Render one "LEVEL: n" line per level present, in LEVELS order."""
    lines = []
    for level in LEVELS:
        if level in counts:
            lines.append("%s: %d" % (level, counts[level]))
    return "\n".join(lines)


def render_rate(rate):
    """Render a rate as a percentage with one decimal, e.g. "12.5%"."""
    return "%.1f%%" % (rate * 100)


def analyze(text):
    """Parse text and return {"entries", "counts", "error_rate"}.

    Malformed log lines are the caller's error: the ValueError raised
    during parsing must propagate to the caller unchanged.
    """
    try:
        entries = parse_log(text)
    except ValueError:
        return {"entries": [], "counts": {}, "error_rate": 0.0}
    counts = count_by_level(entries)
    return {"entries": entries, "counts": counts, "error_rate": error_rate(entries)}


def summary(text):
    """Return a printable summary: the counts block, a blank line, then
    "errors: RATE" where RATE is the error rate rendered by render_rate."""
    result = analyze(text)
    return render_counts(result["counts"]) + "\n\nerrors: " + render_rate(result["error_rate"])
