"""Snapshot backup blobs."""

from storage import save


def backup_snapshot(snapshot):
    """Create a backup blob for a snapshot dict."""
    return "BACKUP:" + save(snapshot)
