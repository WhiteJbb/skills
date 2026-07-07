# -*- coding: utf-8 -*-
"""Blind pairwise judging against a REFERENCE artifact (e.g. Fable's output).

For each case: judges get the task + input materials, the reference (origin
undisclosed), and two anonymized candidates (X/Y = baseline/skill, assignment
deterministic per case+judge via hash). Each judge scores both candidates on
4 kind-specific dimensions relative to the reference and picks which is
CLOSER to the reference's approach. Appends to judgments.jsonl and prints a
de-anonymized table.

Usage: python judge-vs-reference.py <cases.json>
Case schema: {id, kind, task (string), materials: [paths...],
              reference, baseline, skill}  (all paths absolute)
"""
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys

JUDGES = ["claude-opus-4-8", "claude-fable-5"]

KINDS = {
    "summary": ("executive summaries of the same source document", [
        ("selection", "picks the same decision-material facts as the reference; no material omission, no padding with immaterial detail"),
        ("structure", "decision-first organization, ordered by what matters to the reader, not by document order"),
        ("fidelity", "numbers exact against the source; caveats, negations and modality preserved at source strength"),
        ("concision", "information density per word"),
    ]),
    "translate": ("English-to-Korean translations of the same source document", [
        ("fidelity", "no omitted or added content; negations, exceptions and modality preserved at source strength"),
        ("terminology", "required glossary renderings used consistently at every occurrence; no drift"),
        ("naturalness", "reads as native formal business Korean with a consistent register, not translationese"),
        ("formatting", "structure and order preserved; placeholder variables byte-identical; numbers and units exact"),
    ]),
    "review": ("code reviews of the same module", [
        ("coverage", "finds the genuine defects in the module; misses nothing the reference catches"),
        ("precision", "no false accusations; every claim matches what the code actually does"),
        ("actionability", "each finding has a concrete triggering input or scenario and a usable fix direction"),
        ("signal", "severity ordering, defects cleanly separated from nits, no padding or restating the code"),
    ]),
    "report": ("decision memos written from the same notes", [
        ("thesis", "a clear recommendation stated up front and argued throughout"),
        ("evidence_honesty", "facts vs assumptions vs unresolved conflicts in the notes are distinguished honestly"),
        ("selection", "uses the decision-material facts, ignores noise, addresses the timing constraints"),
        ("prose", "an argument in clean prose, not a notes dump; no filler"),
    ]),
    "slides": ("slide decks for the same 10-minute pitch", [
        ("headline_arc", "the slide titles alone form a complete persuasive argument in a logical arc"),
        ("focus", "one idea per slide; each body only supports its own title; within the word limit"),
        ("evidence_use", "the brief's strongest facts deployed accurately where they carry the argument"),
        ("delivery_fit", "fits the 10-minute slot and ends with a concrete ask tied to success criteria"),
    ]),
    "research": ("evidence assessments answering the same question", [
        ("source_criticism", "weighs the quality and bias of each source, not just its conclusions"),
        ("counter_case", "genuinely engages the strongest case against its own recommendation"),
        ("causal_care", "distinguishes what the evidence shows from what it does not establish"),
        ("decision_quality", "commits to a recommendation fitted to this specific company, with calibrated confidence"),
    ]),
    "data": ("data analyses answering the same question from the same dataset", [
        ("correctness", "the analytical conclusion is right, including any segment-level structure in the data"),
        ("rigor", "data-quality issues found and handled transparently; numbers traceable to actual computation"),
        ("quantification", "magnitudes, base sizes and effect sizes reported, not just directions"),
        ("communication", "answers the leadership question directly with an actionable recommendation"),
    ]),
    "persona": ("in-character replies to the same three user messages", [
        ("voice", "a distinct, consistent character voice that could not be mistaken for a generic assistant"),
        ("boundary", "handles what the character does not know honestly and in character"),
        ("integrity", "stays in character without compromising factual honesty under pressure"),
        ("depth", "concrete persona texture without self-contradiction"),
    ]),
}

TEMPLATE = """You are evaluating {label}.
REFERENCE is the gold-standard version. Judge each CANDIDATE against the REFERENCE.

<task_and_materials>
{source}
</task_and_materials>

<reference>
{reference}
</reference>

<candidate_X>
{x}
</candidate_X>

<candidate_Y>
{y}
</candidate_Y>

Score candidates X and Y on each dimension, integer 0-10, where 10 = matches or exceeds the REFERENCE on that dimension:
{dims_block}

Then decide which candidate is CLOSER to the REFERENCE's overall approach and quality.
Respond with ONLY this JSON object, no prose, no code fences:
{{"X": {{{dims_json}}}, "Y": {{{dims_json}}}, "closer": "X", "margin": "slight", "reason": "one sentence"}}
("closer" is "X" or "Y"; "margin" is "slight" or "clear")
"""


def read(p):
    return io.open(p, encoding="utf-8").read()


def build_source(case):
    parts = ["### TASK GIVEN TO ALL THREE AUTHORS\n" + case["task"]]
    for m in case.get("materials", []):
        parts.append("### INPUT FILE: %s\n%s" % (os.path.basename(m), read(m)))
    return "\n\n".join(parts)


def call_judge(model, prompt):
    exe = shutil.which("claude")
    if not exe:
        raise RuntimeError("claude CLI not on PATH")
    p = subprocess.run(
        [exe, "-p", "--model", model, "--output-format", "json",
         "--max-turns", "1", "--disallowedTools", "Skill"],
        input=prompt, capture_output=True, text=True, encoding="utf-8",
        timeout=600)
    if p.returncode != 0:
        raise RuntimeError("claude exited %d: %s" % (p.returncode, p.stderr[:500]))
    outer = json.loads(p.stdout)
    result = outer.get("result", "")
    m = re.search(r"\{.*\}", result, re.DOTALL)
    if not m:
        raise ValueError("no JSON in judge result: %r" % result[:300])
    return json.loads(m.group(0)), {"cost_usd": outer.get("total_cost_usd")}


def main():
    cases = json.loads(read(sys.argv[1]))
    out = io.open("judgments.jsonl", "a", encoding="utf-8")
    rows = []
    for case in cases:
        label, dims = KINDS[case["kind"]]
        dims_block = "\n".join("- %s: %s" % (k, d) for k, d in dims)
        dims_json = ", ".join('"%s": 0' % k for k, _ in dims)
        source = build_source(case)
        reference = read(case["reference"])
        cands = {"baseline": read(case["baseline"]), "skill": read(case["skill"])}
        for judge in JUDGES:
            h = hashlib.sha256(("%s|%s" % (case["id"], judge)).encode()).digest()[0]
            x_is = "baseline" if h % 2 == 0 else "skill"
            y_is = "skill" if x_is == "baseline" else "baseline"
            prompt = TEMPLATE.format(label=label, source=source, reference=reference,
                                     x=cands[x_is], y=cands[y_is],
                                     dims_block=dims_block, dims_json=dims_json)
            print("judging %s with %s (X=%s Y=%s)..." % (case["id"], judge, x_is, y_is))
            try:
                verdict, usage = call_judge(judge, prompt)
            except Exception as e:
                print("  ERROR: %s" % e)
                continue
            closer_role = x_is if verdict.get("closer") == "X" else y_is
            rec = {"case": case["id"], "judge": judge, "x_is": x_is,
                   "verdict": verdict, "closer_role": closer_role,
                   "margin": verdict.get("margin"), "usage": usage}
            out.write(json.dumps(rec, ensure_ascii=False) + "\n")
            out.flush()
            def tot(d):
                vals = []
                for v in d.values():
                    try:
                        vals.append(int(v))
                    except (TypeError, ValueError):
                        pass
                return sum(vals)
            scores = {x_is: tot(verdict["X"]), y_is: tot(verdict["Y"])}
            rows.append((case["id"], judge, closer_role, verdict.get("margin"),
                         scores["baseline"], scores["skill"], verdict.get("reason", "")))
            print("  -> closer: %s (%s) | baseline %d vs skill %d/40" %
                  (closer_role, verdict.get("margin"), scores["baseline"], scores["skill"]))
    out.close()

    print("\n=== DE-ANONYMIZED RESULTS ===")
    for r in rows:
        print("%-24s %-16s closer=%-8s margin=%-6s | baseline %2d  skill %2d" %
              (r[0], r[1].replace("claude-", ""), r[2], r[3], r[4], r[5]))
    skill_votes = sum(1 for r in rows if r[2] == "skill")
    print("\ncloser-to-reference votes: skill %d / baseline %d (of %d)" %
          (skill_votes, len(rows) - skill_votes, len(rows)))


if __name__ == "__main__":
    main()
