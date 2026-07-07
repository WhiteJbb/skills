"""Command-line entry point."""

import sys

from storage import save


def render_output(records):
    """Render records for terminal display."""
    return "== records ==\n" + save(records)


def main(argv):
    print(render_output([list(argv)]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
