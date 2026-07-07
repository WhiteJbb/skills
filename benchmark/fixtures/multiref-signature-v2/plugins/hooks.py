"""Plugin hook registry.

Hooks are plain callables registered by name; run_hook dispatches to
whatever is registered.
"""

from storage import save

HOOKS = {"persist": save}


def run_hook(name, payload):
    """Run a registered hook by name on the payload."""
    return "HOOK[%s]:%s" % (name, HOOKS[name](payload))
