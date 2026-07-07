"""Batch flush pipeline.

The writer is resolved dynamically so deployments can swap it out.
"""

import storage

_WRITER = getattr(storage, "save")


def flush(batch):
    """Flush a batch of rows through the configured writer."""
    return "FLUSH:" + _WRITER(batch)
