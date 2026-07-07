"""Compatibility shims for pre-2.0 integrations.

Do not delete: external scripts still import these entry points.
"""

from storage import save


def legacy_dump(payload):
    """Old-style dump kept for external callers."""
    return save(payload)
