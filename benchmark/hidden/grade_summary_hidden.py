"""Hidden grader for the summary-brief task.

Checks summary.md for: (a) coverage of 15 load-bearing anchor facts from
document.md, (b) length budget. Each fact = list of GROUPS; each group is a
list of alternative regexes (case-insensitive, run on lowercased text); the
fact passes iff every group matches at least once. Numeric anchors use
lookaround guards so 310 does not match 3100 etc.
"""
import io
import re
import sys


def main():
    try:
        text = io.open("summary.md", encoding="utf-8").read()
    except (FileNotFoundError, OSError):
        print("FILE FAIL summary.md not found")
        sys.exit(1)

    t = text.lower()
    facts = [
        ("F01-capex-18.4M", [[r"18\.4"]]),
        ("F02-budget-gap", [[r"(?<![\d.])3\.4(?![\d.])", r"\$15(\.0)?\s*m", r"15(\.0)?\s*million"]]),
        ("F03-payback-3.8y", [[r"(?<![\d.])3\.8(?![\d.])"]]),
        ("F04-helix-volume", [[r"helix"], [r"2,?400"]]),
        ("F05-helix-exit-clause", [[r"exit", r"terminat", r"walk[- ]?away", r"cancel", r"opt[- ]?out",
                                    r"break clause", r"withdraw", r"18[- ]?month", r"month 18"]]),
        ("F06-utilization-92", [[r"(?<![\d.])92(?![\d.])"]]),
        ("F07-overtime-310K", [[r"(?<![\d.])310(?![\d.])"]]),
        ("F08-capacity-3100", [[r"3,?100"]]),
        ("F09-permit-risk", [[r"permit", r"wastewater"],
                             [r"march", r"renew", r"deni", r"reject", r"2027"]]),
        ("F10-competitor-danvers", [[r"danvers"]]),
        ("F11-labor-risk", [[r"(?<![\d.])24(?![\d.])"],
                            [r"hir", r"staff", r"labor", r"operator", r"agency",
                             r"(?<![\d.])2\.1(?![\d.])"]]),
        ("F12-copack-bridge", [[r"co[- ]?pack", r"northgate", r"outsourc"],
                               [r"bridge", r"interim", r"during construction",
                                r"(?<![\d.])2\.9(?![\d.])"]]),
        ("F13-fx-exposure", [[r"eur", r"hedg", r"currency", r"\bfx\b", r"foreign exchange"]]),
        ("F14-timeline-14mo", [[r"14[- ]?month"]]),
        ("F15-phased-recommendation", [[r"(?<![\d.])6\.2(?![\d.])"],
                                       [r"defer", r"phase", r"staged", r"long[- ]?lead",
                                        r"split", r"balance"]]),
    ]

    passed = 0
    failed = []
    for name, groups in facts:
        ok = all(any(re.search(p, t) for p in alts) for alts in groups)
        print("%s %s" % (name, "PASS" if ok else "FAIL"))
        if ok:
            passed += 1
        else:
            failed.append(name)

    words = len(text.split())
    len_ok = words <= 260
    print("LEN %s (%d words, limit 260)" % ("PASS" if len_ok else "FAIL", words))

    print("COVERAGE %d/15" % passed)
    if failed:
        print("MISSING: %s" % ", ".join(failed))
    sys.exit(0 if (passed == 15 and len_ok) else 1)


if __name__ == "__main__":
    main()
