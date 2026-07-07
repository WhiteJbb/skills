"""Grader for the audit-seeded-bugs-v2 task.

Prints one PASS/FAIL line per seeded bug plus a BASELINE line for
previously-correct behavior, then a FOUND k/7 summary. Exit code 0 only
when all seven bugs are fixed and the baseline behavior is intact.
Every graded check reloads the module chain so state (mutable defaults,
class attributes) cannot leak between checks.
"""

import importlib
import os
import sys

sys.path.insert(0, os.getcwd())

RESULTS = []


def fresh():
    """Reload events -> windows -> stats -> report; return the modules."""
    import events
    import windows
    import stats
    import report
    e = importlib.reload(events)
    w = importlib.reload(windows)
    s = importlib.reload(stats)
    r = importlib.reload(report)
    return e, w, s, r


def graded(label, fn):
    try:
        fn()
        RESULTS.append((label, True))
        print("%s: PASS" % label)
    except Exception as exc:
        RESULTS.append((label, False))
        print("%s: FAIL (%s: %s)" % (label, type(exc).__name__, exc))


def ev(event_id, level, duration, message):
    return {"id": event_id, "level": level, "duration": duration, "message": message}


def bug1_early_return():
    events, _, _, _ = fresh()
    data = [ev("e1", "INFO", 10, "a"), ev("e2", "ERROR", 20, "b"), ev("e3", "INFO", 30, "c")]
    assert events.matching_ids(data, "INFO") == ["e1", "e3"], "must return ALL matching ids"


def bug2_tiebreak_direction():
    _, _, stats, _ = fresh()
    ranked = stats.rank_users({"alice": 2, "bob": 2, "carol": 3})
    assert ranked == [("carol", 3), ("alice", 2), ("bob", 2)], \
        "ties must break alphabetically (a before z), got %r" % (ranked,)


def bug3_swallowed_error():
    events, _, _, _ = fresh()
    try:
        events.load_events(["e1 ERROR 5 boom", "garbage line here now"])
    except ValueError:
        return
    raise AssertionError("load_events must raise ValueError for a malformed line")


def bug4_shared_default():
    events, _, _, _ = fresh()
    first = events.EventFilter()
    first.add_exclude("DEBUG")
    second = events.EventFilter()
    assert second.exclude == [], "a new instance must not inherit another instance's excludes"


def bug5_empty_percentile():
    _, _, stats, _ = fresh()
    assert stats.p95([]) == 0, "p95 of an empty list must be 0"


def bug6_drops_newest():
    _, windows, _, _ = fresh()
    data = [ev("e1", "INFO", 10, "a"), ev("e2", "INFO", 20, "b"), ev("e3", "INFO", 30, "c")]
    got = windows.recent(data, 2)
    assert got == data[1:], "recent(n) must include the newest event, got %r" % ([e["id"] for e in got],)


def bug7_snapshot_aliasing():
    _, windows, _, _ = fresh()
    collector = windows.Collector()
    collector.add(ev("e1", "INFO", 10, "a"))
    snap = collector.snapshot()
    snap.append(ev("x", "INFO", 1, "intruder"))
    assert collector.count() == 1, "mutating the snapshot must not affect the collector"


def baseline_intact():
    events, windows, stats, report = fresh()
    # events contracts
    parsed = events.parse_event("e9 ERROR 250 disk full")
    assert parsed == {"id": "e9", "level": "ERROR", "duration": 250, "message": "disk full"}
    for bad in ("nope", "e1 BOGUS 5 x", "e1 ERROR x5 msg"):
        try:
            events.parse_event(bad)
            raise AssertionError("parse_event must reject %r" % bad)
        except ValueError:
            pass
    good_lines = ["e1 INFO 100 start", "", "e2 ERROR 300 boom", "e3 INFO 200 done"]
    loaded = events.load_events(good_lines)
    assert [e["id"] for e in loaded] == ["e1", "e2", "e3"], "blank-line skip broken"
    assert events.format_event(parsed) == "[ERROR] e9: disk full (250ms)"
    assert events.matching_ids([ev("e1", "INFO", 1, "a")], "INFO") == ["e1"]
    explicit = events.EventFilter(["DEBUG"])
    assert explicit.allows(ev("e1", "INFO", 1, "a")) is True
    assert explicit.allows(ev("e2", "DEBUG", 1, "b")) is False
    assert [e["id"] for e in explicit.apply(loaded)] == ["e1", "e2", "e3"]
    # windows contracts
    assert windows.recent([], 2) == []
    assert windows.recent(loaded, 0) == []
    buckets = windows.bucket_by(loaded, 100)
    assert sorted(buckets) == [1, 2, 3] and [e["id"] for e in buckets[3]] == ["e2"]
    off_boundary = windows.bucket_by([ev("e9", "INFO", 250, "odd")], 100)
    assert sorted(off_boundary) == [2] and off_boundary[2][0]["id"] == "e9"
    try:
        windows.bucket_by(loaded, 0)
        raise AssertionError("bucket_by must reject non-positive width")
    except ValueError:
        pass
    collector = windows.Collector()
    collector.add(loaded[0])
    assert collector.count() == 1
    assert collector.snapshot() == [loaded[0]]
    # stats contracts
    assert stats.count_by_level(loaded) == {"INFO": 2, "ERROR": 1}
    assert stats.mean_duration([]) == 0.0
    assert abs(stats.mean_duration(loaded) - 200.0) < 1e-9
    assert stats.p95([10]) == 10
    assert stats.p95(list(range(1, 21))) == 20
    assert stats.rank_users({"a": 1, "b": 5}) == [("b", 5), ("a", 1)]
    assert abs(stats.error_share(loaded) - 1.0 / 3.0) < 1e-9
    assert stats.error_share([]) == 0.0
    # report contracts
    assert report.render_counts({"INFO": 2, "ERROR": 1}) == "INFO: 2\nERROR: 1"
    assert report.render_share(0.125) == "12.5%"
    assert report.digest(loaded) == "INFO: 2\nERROR: 1\n\nerrors: 33.3% | mean: 200.0ms"


def main():
    graded("BUG1 early-return-all-matches", bug1_early_return)
    graded("BUG2 tiebreak-direction", bug2_tiebreak_direction)
    graded("BUG3 swallowed-parse-error", bug3_swallowed_error)
    graded("BUG4 shared-default-excludes", bug4_shared_default)
    graded("BUG5 empty-percentile-crash", bug5_empty_percentile)
    graded("BUG6 window-drops-newest", bug6_drops_newest)
    graded("BUG7 snapshot-aliasing", bug7_snapshot_aliasing)
    graded("BASELINE intact-behavior", baseline_intact)
    fixed = sum(1 for label, ok in RESULTS if ok and label.startswith("BUG"))
    baseline_ok = all(ok for label, ok in RESULTS if label.startswith("BASELINE"))
    print("FOUND %d/7 bugs fixed; baseline %s" % (fixed, "PASS" if baseline_ok else "FAIL"))
    if fixed == 7 and baseline_ok:
        print("HIDDEN OK")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
