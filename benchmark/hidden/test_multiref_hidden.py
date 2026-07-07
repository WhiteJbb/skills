import inspect
import os
import sys

sys.path.insert(0, os.getcwd())
from storage import save
from exporter import export_rows
from backup import backup_snapshot
from cli import render_output
from legacy.compat import legacy_dump


def expect_value_error(fn):
    try:
        fn()
    except ValueError:
        return
    raise AssertionError("expected ValueError")


def run():
    # new signature: format is a required keyword-only parameter
    param = inspect.signature(save).parameters.get("format")
    assert param is not None, "save has no format parameter"
    assert param.kind == inspect.Parameter.KEYWORD_ONLY, "format must be keyword-only"
    assert param.default is inspect.Parameter.empty, "format must be required (no default)"

    # json keeps the original behavior
    assert save({"b": 1, "a": 2}, format="json") == '{"a": 2, "b": 1}'
    # csv rules
    assert save([[1, "x"], [2, "y"]], format="csv") == "1,x\n2,y"
    assert save([], format="csv") == ""
    # anything else raises ValueError
    for bad in ("xml", "JSON", "", None):
        expect_value_error(lambda b=bad: save([[1]], format=b))

    # every call site still produces its original output
    assert export_rows([[1, "a"]]) == 'EXPORT\n[[1, "a"]]'
    assert backup_snapshot({"k": 1}) == 'BACKUP:{"k": 1}'
    assert render_output([["id", "name"]]) == '== records ==\n[["id", "name"]]'
    assert legacy_dump({"old": True}) == '{"old": true}'
    print("HIDDEN OK")


if __name__ == "__main__":
    # report failures on stdout so the harness check-output.txt stays informative
    try:
        run()
    except Exception as exc:
        print("HIDDEN FAIL (%s: %s)" % (type(exc).__name__, exc))
        sys.exit(1)
