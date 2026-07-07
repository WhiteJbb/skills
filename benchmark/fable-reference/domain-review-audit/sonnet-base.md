# Review

## Defects (most severe first)

1. **events.py:51-57 `matching_ids`** — `return ids` is indented inside the `for` loop (not inside the `if`), so the function returns after examining only the first event, ignoring all others.
   Trigger: `matching_ids([{"id":"a","level":"INFO",...},{"id":"b","level":"ERROR",...}], "ERROR")` returns `[]` instead of `["b"]`.
   Fix: dedent `return ids` to after the loop.

2. **windows.py:10 `recent`** — slices `events[-n:-1]`, which excludes the last element entirely; for `n == 1` this returns `[]` instead of the most recent event.
   Trigger: `recent([e1, e2, e3], 1)` returns `[]`; `recent([e1,e2,e3], 2)` returns `[e2]` instead of `[e2, e3]`.
   Fix: use `events[-n:]`.

3. **stats.py:19-28 `p95`** — for an empty `durations` list, `index` is clamped to `len(ranked)-1 == -1` and `ranked[-1]` raises `IndexError`, instead of returning 0 as the docstring requires.
   Trigger: `p95([])` raises `IndexError: list index out of range`.
   Fix: add an explicit `if not ranked: return 0` guard before indexing.

4. **events.py:69 `EventFilter.__init__`** — `exclude=[]` is a mutable default argument shared by every `EventFilter()` created without an explicit `exclude`, contradicting the docstring's "every instance owns an independent exclude list."
   Trigger: `f1 = EventFilter(); f2 = EventFilter(); f1.add_exclude("DEBUG")` — now `f2.allows({"level":"DEBUG",...})` is also `False` because `f1` and `f2` share the same list.
   Fix: use `exclude=None` and set `self.exclude = list(exclude) if exclude is not None else []`.

5. **events.py:44-47 `load_events`** — malformed lines are caught and silently `continue`d, contradicting the docstring's explicit "bad input must never be silently dropped."
   Trigger: `load_events(["e1 ERROR 250 ok", "garbage line"])` silently returns only one event instead of raising `ValueError`.
   Fix: remove the `try/except` (or re-raise) so malformed lines propagate.

6. **windows.py:43-46 `Collector.snapshot`** — returns `self._events` directly rather than a copy, so mutating the returned list mutates the collector's internal state, contradicting the docstring.
   Trigger: `c = Collector(); c.add(e); c.snapshot().clear()` then `c.count()` is now `0`.
   Fix: return `list(self._events)`.

7. **stats.py:31-34 `rank_users`** — `reverse=True` is applied to the whole `(count, user)` key, so tie-breaking sorts names z-before-a, contradicting the docstring's "ties broken alphabetically (a before z)."
   Trigger: `rank_users({"zack": 2, "abby": 2})` returns `[("zack", 2), ("abby", 2)]` instead of `[("abby", 2), ("zack", 2)]`.
   Fix: sort with `key=lambda item: (-item[1], item[0])` (no `reverse`), or reverse only the count component.

## Nits

- events.py:69 — mutable default argument style issue is functionally covered above, but generally avoid mutable defaults even where not user-facing.
- report.py — no defects found; module is a thin, consistent composition of `events`/`stats`.
