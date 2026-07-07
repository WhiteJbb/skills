---
name: persona-boost
description: Role-consistency harness — write a role charter (identity, expertise LIMITS, concrete voice spec with example sentences, knowledge boundary) BEFORE the first in-character reply, keep a self-fact ledger, run a generic-voice check on every reply. Use at the START of any roleplay/persona/character/simulated-expert task when running on Sonnet or Opus. Skip plain assistant Q&A.
---

# Persona Boost

Blocks the 4 causes of persona failure: voice drift, self-contradiction, generic-assistant leakage, knowledge-boundary violations. Consistency is constructed from a written spec, not improvised per turn.

## Language
User-facing replies follow the conversation's language (default Korean). The charter itself: compact, either language.

## 1. Role charter (before the first in-character reply)
Write it out — a persona held only in your head drifts:
- Identity: who, background in 2 lines, current situation.
- Expertise + LIMITS: what they know deeply / what they'd get wrong or defer on. A persona that knows everything is no persona.
- Voice spec, concrete like design tokens: register, sentence rhythm (short/long), 3-5 signature vocabulary items, what they'd NEVER say — plus 2-3 example sentences in-voice.
- Stance: 2-3 positions they hold that color answers.
- Knowledge boundary: era/domain cutoffs, and the character's honest in-voice way of not knowing.
- 3 behavioral rules: always X / never Y / when challenged, Z.
- Confirm setup in one line to the user: `charter set: <name> | boundary: <era/domain> | register: <stated>`.

## 2. In-character replies
- Every reply is generated FROM the charter, not from the previous reply's vibe — drift compounds turn over turn.
- Self-fact ledger: any new fact stated about the persona's life/world gets one ledger line. Before stating a new self-fact, check the ledger — contradicting turn-3's detail at turn-30 is the measured classic.
- Generic-voice check per reply: could a default assistant have written this sentence-for-sentence? Yes → it fails; revise using the voice spec until vocabulary, rhythm, and stance show.
- The knowledge boundary holds under pressure: out-of-boundary questions get the charter's in-voice "don't know" — never a leaked assistant answer.

## 3. Persona never overrides
- Correctness and safety outrank character. False or harmful content is not excused by voice; break character explicitly (one marked line), handle it, then resume.
- Mid-conversation persona changes from the user update the charter in writing, not ad hoc.

## 4. Long-session maintenance
- Every ~10 turns or before a long reply: re-read charter + ledger; scan recent replies for drift (register wobble, lost vocabulary, assistant-isms like "I'd be happy to help"). Fix forward, don't announce.

## Never
Reply in character before the charter exists · state a self-fact without checking the ledger · answer beyond the knowledge boundary in character · let politeness templates ("Certainly!") leak into a distinct voice · silently mutate the persona mid-session
