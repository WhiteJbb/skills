# Review: events.py / windows.py / stats.py / report.py

## Bugs (most severe first)

1. **stats.py:26-28 `p95`** — Crashes with `IndexError` on empty input instead of returning `0` as the docstring requires.
   Scenario: `p95([])` → `ranked = []`, `index = int(0*0.95) = 0`, `0 >= len(ranked)` is true so `index` is set to `len(ranked)-1 = -1`, then `ranked[-1]` on an empty list raises `IndexError: list index out of range`.
   Fix: check `if not ranked: return 0` before computing `index`.

2. **windows.py:10 `recent`** — Off-by-one drops the newest (last) event in every case, contradicting "newest last" / "return them all" guarantees.
   Scenario: `recent([1,2,3,4,5], 3)` returns `[3, 4]` (missing `5`); `recent([1,2,3], 10)` returns `[1, 2]` (missing `3`) even though `n` exceeds the count.
   Fix: use `events[-n:]` instead of `events[-n:-1]`.

3. **events.py:57 `matching_ids`** — `return ids` is indented inside the `for` loop, so the function returns after examining only the first event, regardless of whether it matched.
   Scenario: `matching_ids([{"level":"INFO",...}, {"level":"ERROR","id":"e2"}, {"level":"ERROR","id":"e3"}], "ERROR")` returns `[]` instead of `["e2", "e3"]`.
   Fix: dedent `return ids` to run after the loop completes.

4. **events.py:44-47 `load_events`** — Silently `continue`s past malformed lines by catching and swallowing `ValueError`, directly violating the stated contract "bad input must never be silently dropped."
   Scenario: `load_events(["e1 ERROR 250 disk full", "bad line", "e2 INFO 10 ok"])` returns 2 parsed events with the malformed line dropped, instead of raising `ValueError`.
   Fix: remove the `try/except`, let `parse_event`'s `ValueError` propagate.

5. **events.py:69 `EventFilter.__init__`** — Mutable default argument `exclude=[]` is shared across every instance created without an explicit `exclude`, breaking the documented guarantee that "every instance owns an independent exclude list."
   Scenario: `f1 = EventFilter(); f2 = EventFilter(); f1.add_exclude("ERROR")` causes `f2.exclude` to also contain `"ERROR"` even though `f2` was never touched.
   Fix: default to `None` and set `self.exclude = exclude if exclude is not None else []` in `__init__`.

6. **windows.py:46 `Collector.snapshot`** — Returns the internal `_events` list directly instead of a copy, violating "mutating the returned list must not affect the collector."
   Scenario: `c.add("x"); snap = c.snapshot(); snap.append("y")` makes `c.count()` become `2` after only one `add` call.
   Fix: `return list(self._events)`.

7. **stats.py:34 `rank_users`** — `reverse=True` flips both parts of the sort key, so ties are broken with the alphabetically *last* name first, contradicting "ties broken alphabetically (a before z)."
   Scenario: `rank_users({"annie": 5, "bob": 5})` returns `[("bob", 5), ("annie", 5)]` instead of `[("annie", 5), ("bob", 5)]`.
   Fix: sort by `key=lambda item: (-item[1], item[0])` without `reverse=True` (or negate only the count).

## Nits

- `events.py:28` — `duration.isdigit()` accepts non-ASCII "digit" characters (e.g. superscripts) that `int()` cannot parse, which would raise an uncaught `ValueError` from `int(duration)` rather than the intended "bad duration" message.
- `events.py:69` — parameter named `exclude` shadows no builtin but reads oddly alongside the `add_exclude` method; naming only, no behavior issue beyond the mutable-default bug above.

lenses: 6/6 run | findings: 7 confirmed / 0 plausible | rounds until dry: 2
