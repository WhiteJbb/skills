"""Grader for the md-ref-backtick task (Python-Markdown issue #495).

Bug cases = shortcut reference links whose label contains a code span
(fail at the pinned parent commit fb6b27a, pass at the upstream fix
07dfa4e). Baseline cases = surrounding behavior that passes at BOTH
commits - a fix that breaks any of them is a regression.
Exit 0 only when all 3 bug cases pass and the baseline is intact.
"""

import os
import sys

sys.path.insert(0, os.getcwd())
import markdown

RESULTS = []


def render(src):
    return markdown.markdown(src)


def check(label, src, want):
    got = render(src)
    ok = got == want
    RESULTS.append((label, ok))
    if ok:
        print("%s: PASS" % label)
    else:
        print("%s: FAIL (got %r, want %r)" % (label, got, want))


def main():
    # bug cases (issue #495)
    check("BUG1 ref-label-is-code",
          "[`Text`]\n\n[`Text`]: http://example.com",
          '<p><a href="http://example.com"><code>Text</code></a></p>')
    check("BUG2 ref-label-contains-code",
          "[some `Text`]\n\n[some `Text`]: http://example.com",
          '<p><a href="http://example.com">some <code>Text</code></a></p>')
    check("BUG3 ref-label-code-first",
          "[`Text` after]\n\n[`Text` after]: http://example.com",
          '<p><a href="http://example.com"><code>Text</code> after</a></p>')
    # BUG4/5 discriminate complete vs incomplete fixes: a code span containing
    # <, >, or & is HTML-escaped at match time, so a fix that derives the
    # definition-side id from raw text (and doesn't unescape the usage side)
    # silently fails to link. Surfaced by the fresh-context skeptic in the
    # 2026-07-07 OSS run, not by the original grader. Upstream 07dfa4e handles it.
    check("BUG4 ref-label-code-with-angle",
          "[`<div>`]\n\n[`<div>`]: http://example.com",
          '<p><a href="http://example.com"><code>&lt;div&gt;</code></a></p>')
    check("BUG5 ref-label-code-with-amp",
          "[`a&b`]\n\n[`a&b`]: http://example.com",
          '<p><a href="http://example.com"><code>a&amp;b</code></a></p>')
    # baseline: must not regress (all of these pass before AND after the fix)
    check("BASE1 inline-link-full-code",
          "[`test`](link)",
          '<p><a href="link"><code>test</code></a></p>')
    check("BASE2 inline-link-partial-code",
          "[some `test`](link)",
          '<p><a href="link">some <code>test</code></a></p>')
    check("BASE3 inline-link-single-backtick",
          "[some `test](link)",
          '<p><a href="link">some `test</a></p>')
    check("BASE4 ref-single-backtick",
          "[some `Text]\n\n[some `Text]: http://example.com",
          '<p><a href="http://example.com">some `Text</a></p>')
    check("BASE5 two-part-ref-with-code",
          "[`config.txt`][config]\n\n[config]: /files/config.txt",
          '<p><a href="/files/config.txt"><code>config.txt</code></a></p>')
    check("BASE6 plain-code-span",
          "Use `x = 1` here.",
          '<p>Use <code>x = 1</code> here.</p>')
    check("BASE7 code-span-with-brackets",
          "`a[0]` and `d[k]`",
          '<p><code>a[0]</code> and <code>d[k]</code></p>')
    check("BASE8 double-backtick-span",
          "``a `b` c``",
          '<p><code>a `b` c</code></p>')
    check("BASE9 plain-ref-link",
          "[docs]\n\n[docs]: /docs",
          '<p><a href="/docs">docs</a></p>')
    check("BASE10 plain-inline-link",
          "[docs](/docs)",
          '<p><a href="/docs">docs</a></p>')
    check("BASE11 two-part-ref-plain",
          "[the file][config]\n\n[config]: /files/config.txt",
          '<p><a href="/files/config.txt">the file</a></p>')

    bug_total = sum(1 for label, _ in RESULTS if label.startswith("BUG"))
    fixed = sum(1 for label, ok in RESULTS if ok and label.startswith("BUG"))
    baseline_ok = all(ok for label, ok in RESULTS if label.startswith("BASE"))
    print("FOUND %d/%d bug cases fixed; baseline %s" % (fixed, bug_total, "PASS" if baseline_ok else "FAIL"))
    if fixed == bug_total and baseline_ok:
        print("HIDDEN OK")
        return 0
    return 1


if __name__ == "__main__":
    try:
        code = main()
    except Exception as exc:
        print("HIDDEN FAIL (%s: %s)" % (type(exc).__name__, exc))
        code = 1
    sys.exit(code)
