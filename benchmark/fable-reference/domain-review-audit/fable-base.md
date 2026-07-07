# Review: events.py, windows.py, stats.py, report.py

## Defects (most severe first)

### 1. `matching_ids` returns after the first event — `events.py:57`
The `return ids` is indented inside the `for` loop, so the function returns after inspecting only the first event (and returns `None` for an empty list) instead of collecting all matching ids.
- **Trigger:** `matching_ids([{"level":"INFO","id":"e1"},{"level":"ERROR","id":"e2"}], "ERROR")` → `[]` (expected `["e2"]`); `matching_ids([], "ERROR")` → `None` (expected `[]`).
- **Fix:** dedent `return ids` out of the loop.

### 2. `load_events` silently drops malformed lines — `events.py:46-47`
The `except ValueError: continue` swallows parse errors, directly violating the contract "a malformed line raises ValueError; bad input must never be silently dropped."
- **Trigger:** `load_events(["e1 ERROR 250 ok", "garbage line here bad-duration"])` returns one event instead of raising.
- **Fix:** remove the try/except and let `parse_event`'s ValueError propagate.

### 3. `recent` drops the newest event — `windows.py:10`
`events[-n:-1]` excludes the last element, so the most recent event is always missing and the function returns n−1 items (empty when n == len == 1).
- **Trigger:** `recent([a, b, c], 2)` → `[b]` (expected `[b, c]`); `recent([a], 1)` → `[]`.
- **Fix:** use `events[-n:]`.

### 4. `Collector.snapshot` returns the internal list, not a copy — `windows.py:46`
The contract says mutating the returned list must not affect the collector, but the internal `_events` list itself is returned.
- **Trigger:** `s = c.snapshot(); s.clear(); c.count()` → 0 even though events were added.
- **Fix:** return `list(self._events)`.

### 5. `EventFilter` shares one exclude list across instances — `events.py:69`
The mutable default `exclude=[]` is evaluated once, so every filter constructed without an argument shares the same list, violating "every instance owns an independent exclude list"; `add_exclude` then mutates all such filters at once (and even an explicitly passed list is aliased, not copied).
- **Trigger:** `f1 = EventFilter(); f2 = EventFilter(); f1.add_exclude("DEBUG"); f2.allows({"level":"DEBUG"})` → `False` (expected `True`).
- **Fix:** use `exclude=None` and `self.exclude = list(exclude) if exclude else []`.

### 6. `p95` raises IndexError on an empty list — `stats.py:24-28`
For `durations == []`, `index = 0`, the clamp sets it to `-1`, and `ranked[-1]` raises IndexError instead of returning 0 as the contract requires.
- **Trigger:** `p95([])` → IndexError (expected `0`).
- **Fix:** return `0` early when the list is empty, before indexing.

### 7. `rank_users` breaks ties in reverse alphabetical order — `stats.py:34`
`reverse=True` applied to the `(count, user)` key reverses the alphabetical tie-break too, so ties come out z-before-a instead of a-before-z.
- **Trigger:** `rank_users({"alice": 3, "bob": 3})` → `[("bob", 3), ("alice", 3)]` (expected alice first).
- **Fix:** sort without `reverse` using key `(-count, user)`.

## Nits

- `events.py:28` — `str.isdigit()` accepts non-ASCII digit characters (e.g. `"²"`, `"٣"`); some of those then fail inside `int()`, producing a ValueError with the wrong message. Consider an explicit `int()` with try/except or an ASCII-digit check.
- `events.py:72` — `EventFilter.__init__` does not validate the levels in a caller-supplied `exclude` list, while `add_exclude` does; validation is inconsistent between the two entry points.
