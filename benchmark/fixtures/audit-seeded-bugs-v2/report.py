"""Rendering of analytics results."""

from events import LEVELS
from stats import count_by_level, error_share, mean_duration


def render_counts(counts):
    """Render one "LEVEL: n" line per level present, in LEVELS order."""
    lines = []
    for level in LEVELS:
        if level in counts:
            lines.append("%s: %d" % (level, counts[level]))
    return "\n".join(lines)


def render_share(share):
    """Render a share as a percentage with one decimal, e.g. "12.5%"."""
    return "%.1f%%" % (share * 100)


def digest(events):
    """Return a printable digest: the counts block, a blank line, then
    "errors: SHARE | mean: Xms" (mean with one decimal)."""
    return "%s\n\nerrors: %s | mean: %.1fms" % (
        render_counts(count_by_level(events)),
        render_share(error_share(events)),
        mean_duration(events),
    )
