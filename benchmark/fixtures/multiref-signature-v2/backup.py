"""Snapshot backup blobs."""

from storage import save as persist


def backup_snapshot(snapshot):
    """Create a backup blob for a snapshot dict."""
    return "BACKUP:" + persist(snapshot)
