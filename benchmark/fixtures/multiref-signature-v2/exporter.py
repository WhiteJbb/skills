"""Tabular export built on the storage encoder."""

from storage import save


def export_rows(rows):
    """Export tabular rows as a stored document."""
    return "EXPORT\n" + save(rows)
