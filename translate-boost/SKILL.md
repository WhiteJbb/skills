---
name: translate-boost
description: Translation-fidelity harness — fix register, audience, and a term glossary BEFORE translating, meaning-first rendering, then two SEPARATE passes: naturalness (target only) and fidelity (against source), with segment-count and number checks. Use at the START of any translation/localization task when running on Sonnet or Opus. Skip single-word lookups.
---

# Translate Boost

Blocks the 4 causes of bad translation: literal rendering, register mismatch, terminology drift, silent omission. A translation is judged twice — as target-language writing, and against the source — so it is checked twice, separately.

## Language
User-facing responses in Korean. The translation is in the requested target language.

## 1. Pre-pass contract (before translating a sentence)
- Three lines: audience / register & tone (Korean: 격식체·해요체·평어 explicitly; English: formal/neutral/casual) / domain.
- Glossary: recurring terms, proper nouns, titles — ONE fixed rendering each. Ambiguous terms: decide now, note the choice. Honorific and pronoun policy fixed here.
- Numbers, units, dates, currency: convert or preserve — decide once, apply throughout.

## 2. Translate meaning-first
- Render what a native writer would say, not the source's word order. Output that reads like a translation is a draft, not a translation.
- Idioms/metaphors: equivalent target idiom, or plain meaning — never literal. Wordplay/tone: preserve the EFFECT; note in one line where an effect was unpreservable.
- Modality survives exactly: the strength of "may / must / failed to / unless" is fidelity-critical.
- Splitting/merging sentences is allowed; dropping or adding content is not. Source formatting (headings, emphasis, lists) preserved; placeholders/variables like {name} byte-identical.

## 3. Pass A — naturalness (target only)
- Re-read the full translation WITHOUT the source, as a native reader. Fix every sentence you stumble on.
- Translationese tells: source word order, over-literal connectives, register wobble between sentences.

## 4. Pass B — fidelity (against source)
- Segment-by-segment: every source segment has a counterpart — count them (N/N). Silent omission is the #1 translation defect and is invisible in Pass A by design; that is why the passes are separate.
- Numbers, dates, names, negations checked one-by-one against the source.
- Glossary sweep: search the output for each glossary term — every occurrence uses the fixed rendering (countable, K/K).

## 5. Report
- Deliverable hygiene: the translation file contains only the translation — notes and the status line go in your chat response, never inside the file.
- 2 lines (Korean): choices made (register, notable term decisions, unpreservable effects) / anything uncertain.
- End the chat response with: `segments: N/N | glossary: K/K consistent | numbers/negations verified: Y | register: <stated>`

## Never
Translate before fixing register + glossary · render an idiom literally · let a term drift mid-document · drop or add content silently · merge the naturalness and fidelity passes into one · translate placeholder variables
