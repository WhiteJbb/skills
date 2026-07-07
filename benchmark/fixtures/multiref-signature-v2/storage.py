"""Storage serialization for the reporting toolkit."""

import json


def save(data):
    """Serialize data for storage and return the encoded string."""
    return json.dumps(data, sort_keys=True)
