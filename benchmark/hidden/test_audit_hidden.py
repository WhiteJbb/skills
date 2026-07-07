"""Grader for the audit-seeded-bugs task.

Prints one PASS/FAIL line per seeded bug plus a BASELINE line for
previously-correct behavior, then a FOUND k/5 summary. Exit code 0 only
when all five bugs are fixed and the baseline behavior is intact.
Every graded check reloads the module chain so state (e.g. a mutable
default argument) cannot leak between checks.
"""

import importlib
import os
import sys

sys.path.insert(0, os.getcwd())

RESULTS = []


def fresh():
    """Reload parser -> aggregator -> report so no state leaks between checks."""
    import parser
    import aggregator
    import report
    p = importlib.reload(parser)
    a = importlib.reload(aggregator)
    r = importlib.reload(report)
    return p, a, r


def graded(label, fn):
    try:
        fn()
        RESULTS.append((label, True))
        print("%s: PASS" % label)
    except Exception as exc:
        RESULTS.append((label, False))
        print("%s: FAIL (%s: %s)" % (label, type(exc).__name__, exc))


def bug1_last_line():
    parser, _, _ = fresh()
    entries = parser.parse_log("12:00:00 INFO a\n12:00:01 WARNING b")
    assert len(entries) == 2, "expected 2 entries, got %d" % len(entries)
    assert entries[1]["message"] == "b"


def bug2_threshold_boundary():
    _, aggregator, _ = fresh()
    warning = {"time": "12:00:00", "level": "WARNING", "message": "w"}
    kept = aggregator.entries_at_or_above([warning], "WARNING")
    assert kept == [warning], "an entry exactly at min_level must be included"


def bug3_swallowed_error():
    _, _, report = fresh()
    try:
        report.analyze("this is not a log line\n")
    except ValueError:
        return
    raise AssertionError("analyze() must propagate ValueError for malformed input")


def bug4_mutable_default():
    _, aggregator, _ = fresh()
    info = {"time": "12:00:00", "level": "INFO", "message": "m"}
    aggregator.count_by_level([info])
    second = aggregator.count_by_level([info])
    assert second.get("INFO") == 1, "second call must not see state from the first"


def bug5_empty_division():
    _, aggregator, _ = fresh()
    assert aggregator.error_rate([]) == 0.0


HEALTHY = "09:00:00 INFO start\n\n09:01:00 ERROR boom\n09:02:00 INFO done\n"


def baseline_intact():
    parser, aggregator, report = fresh()
    # parser contracts
    entry = parser.parse_line("09:15:00 ERROR disk full")
    assert entry == {"time": "09:15:00", "level": "ERROR", "message": "disk full"}
    for bad in ("nope", "09:15:00 BOGUS x", "09:15:00 ERROR"):
        try:
            parser.parse_line(bad)
            raise AssertionError("parse_line must reject %r" % bad)
        except ValueError:
            pass
    entries = parser.parse_log(HEALTHY)
    assert [e["message"] for e in entries] == ["start", "boom", "done"], "blank-line skip broken"
    assert parser.latest_time(entries) == "09:02:00"
    assert parser.latest_time([]) is None
    # aggregator contracts (one count_by_level call per fresh() segment)
    counts = aggregator.count_by_level(entries)
    assert counts == {"INFO": 2, "ERROR": 1}
    kept = aggregator.entries_at_or_above(entries, "ERROR")
    assert all(e["level"] != "INFO" for e in kept), "below-threshold entries must be excluded"
    try:
        aggregator.entries_at_or_above(entries, "FATAL")
        raise AssertionError("unknown min_level must raise ValueError")
    except ValueError:
        pass
    assert abs(aggregator.error_rate(entries) - 1.0 / 3.0) < 1e-9
    assert aggregator.top_messages(entries, 2) == [("boom", 1), ("done", 1)]
    assert aggregator.count_matching(entries, "oo") == 1
    # report contracts
    assert report.render_counts({"INFO": 2, "ERROR": 1}) == "INFO: 2\nERROR: 1"
    assert report.render_rate(0.125) == "12.5%"
    parser, aggregator, report = fresh()
    result = report.analyze(HEALTHY)
    assert [e["message"] for e in result["entries"]] == ["start", "boom", "done"]
    assert result["counts"] == {"INFO": 2, "ERROR": 1}
    parser, aggregator, report = fresh()
    assert report.summary(HEALTHY) == "INFO: 2\nERROR: 1\n\nerrors: 33.3%"


def main():
    graded("BUG1 off-by-one-last-line", bug1_last_line)
    graded("BUG2 threshold-boundary", bug2_threshold_boundary)
    graded("BUG3 swallowed-error", bug3_swallowed_error)
    graded("BUG4 mutable-default-state", bug4_mutable_default)
    graded("BUG5 empty-input-division", bug5_empty_division)
    graded("BASELINE intact-behavior", baseline_intact)
    fixed = sum(1 for label, ok in RESULTS if ok and label.startswith("BUG"))
    baseline_ok = all(ok for label, ok in RESULTS if label.startswith("BASELINE"))
    print("FOUND %d/5 bugs fixed; baseline %s" % (fixed, "PASS" if baseline_ok else "FAIL"))
    if fixed == 5 and baseline_ok:
        print("HIDDEN OK")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
