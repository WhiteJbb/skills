"""Hidden grader for the translate-notes task.

Reads source.md (still in the workdir) and translation.md, and checks:
- STRUCT: heading count and bullet count match the source exactly
- PH: every {placeholder} token appears byte-identical, same count as source
- TERM: each glossary term's Korean rendering appears at least as many times
  as the English term occurs in the source (drift to another rendering, or
  leaving the term untranslated, lowers the count and fails). Spaced and
  unspaced variants of compound renderings both count.
- NUM: distinctive numbers survive (lookaround guards; \\b fails next to
  Hangul since Korean chars are \\w in Python re)
Exit 0 iff all checks pass. Per-check lines are printed for post-hoc k/N.
"""
import io
import re
import sys

STRIP_PH = re.compile(r"\{[^}]+\}")

# (check-name, english regex, [korean rendering variants])
TERMS = [
    ("workspace", r"\bworkspaces?\b", ["워크스페이스"]),
    ("ticket", r"\btickets?\b", ["티켓"]),
    ("escalation", r"\bescalations?\b", ["에스컬레이션"]),
    ("billing-account", r"\bbilling accounts?\b",
     ["청구 계정", "청구계정"]),
    ("on-call-schedule", r"\bon-call schedules?\b",
     ["대기 일정", "대기일정"]),
    ("audit-log", r"\baudit logs?\b",
     ["감사 로그", "감사로그"]),
    ("annual-plan", r"\bannual plans?\b",
     ["연간 플랜", "연간플랜"]),
]

NUMS = [
    ("2026.3", r"2026\.3"),
    ("march-30", r"(?<![\d.])30(?![\d.])"),
    ("14-days", r"(?<![\d.])14(?![\d.])"),
    ("50-GB", r"(?<![\d.])50(?![\d.])"),
    ("uptime-99.95", r"99\.95"),
]


def main():
    src = io.open("source.md", encoding="utf-8").read()
    try:
        out = io.open("translation.md", encoding="utf-8").read()
    except (FileNotFoundError, OSError):
        print("FILE FAIL translation.md not found")
        sys.exit(1)

    checks = []

    sh = len(re.findall(r"(?m)^#{1,6} ", src))
    oh = len(re.findall(r"(?m)^#{1,6} ", out))
    checks.append(("STRUCT-headings", sh == oh, "src %d out %d" % (sh, oh)))

    sb = len(re.findall(r"(?m)^\s*[-*] ", src))
    ob = len(re.findall(r"(?m)^\s*[-*] ", out))
    checks.append(("STRUCT-bullets", sb == ob, "src %d out %d" % (sb, ob)))

    for ph in sorted(set(STRIP_PH.findall(src))):
        sc, oc = src.count(ph), out.count(ph)
        checks.append(("PH-%s" % ph, sc == oc, "src %d out %d" % (sc, oc)))

    src_np = STRIP_PH.sub(" ", src)
    out_np = STRIP_PH.sub(" ", out)
    for name, en_pat, ko_variants in TERMS:
        need = len(re.findall(en_pat, src_np, re.IGNORECASE))
        got = sum(out_np.count(v) for v in ko_variants)
        checks.append(("TERM-%s" % name, got >= need, "need>=%d got %d" % (need, got)))

    for name, pat in NUMS:
        checks.append(("NUM-%s" % name, re.search(pat, out) is not None, ""))

    npass = 0
    for name, ok, detail in checks:
        print("%s %s%s" % (name, "PASS" if ok else "FAIL",
                           (" (%s)" % detail) if detail else ""))
        if ok:
            npass += 1
    print("SCORE %d/%d" % (npass, len(checks)))
    sys.exit(0 if npass == len(checks) else 1)


if __name__ == "__main__":
    main()
