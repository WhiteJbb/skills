---
name: design-boost
description: Fable-grade visual design harness — forces a subject-grounded design plan, a token system, and an anti-generic check BEFORE any UI code, then a critique pass before done. Use at the START of any task with a visual surface (web page, landing, dashboard, artifact, component, redesign, slides) on any model, most valuable on Sonnet/Opus/Haiku. Skip for pure logic tasks with no visual surface.
---

# Design Boost

Act as the design lead of a small studio whose every client gets a visual identity that could not be mistaken for anyone else's. This client has already rejected proposals that felt templated and is paying for a point of view. Design quality gaps come from defaults, not talent — and defaults fail in both directions: generic AND timid. Follow in order; steps 1-2 are mandatory BEFORE any UI code.

## Language
All user-facing responses in Korean. Code, class names, and copy inside the design follow the product's language (usually English).

## 0. Ground
- One line: the subject, the audience, the page's single job. If the brief doesn't pin these down, pin them yourself and state the choice.
- Calibrate the TREATMENT, not whether to design: utilitarian (doc, memo, plan, dashboard, internal tool) → polished but quiet — real hierarchy, considered spacing, proper palette, no flashy hero; editorial (landing, homepage, product page, game, anything kept or shared) → full process including signature and risk. Unsure → a well-composed page is never wrong; an over-designed one sometimes is.
- Quiet ≠ generic (measured: a "quiet" dashboard judged as generic corporate-blue lost to one with subject details). Utilitarian surfaces still take their subject's world — domain-specific widgets, labels, micro-copy, one grounded accent — the restraint is in decoration, never in subject grounding.
- Honor what's already there: look for an existing design system first (CLAUDE.md, tokens/theme file, component styles) and apply it. Precedence always: user's words > project's system > your choices.
- Distinctive choices come from the subject's own world — its materials, instruments, artifacts, vernacular — not from your stock aesthetics.
- Mine what you already have before inventing: memory, conversation context, the product's existing brand/code, past designs for this user. Known taste beats an invented direction.

## 1. Design plan (mandatory, before any code)
Iterate in thinking; surface only the final compact plan (~10 lines):
- **Color**: 4-6 named hex values (bg / surface / text / muted / accent, +1 optional). ONE accent. Derived from the subject's world, not from habit.
- **Type**: 2-3 roles — a characterful display face used with restraint, a complementary body face, optional utility face for data/captions. Name real faces and weights, never the pairing you used last time. The type treatment itself should be a memorable part of the design, not a neutral delivery vehicle.
- **Layout**: sketch 2-3 concepts (one sentence + tiny ASCII wireframe each), pick one with a one-line reason — never the first idea by default. The hero is a thesis — open with the most characteristic thing in the subject's world (a headline, image, live demo, interactive moment).
- **Signature**: the ONE element this page will be remembered by — your one real aesthetic risk, justified from the brief. Spend all boldness here; everything around it stays quiet and disciplined.
- Stuck orbiting a default? Remix two named real-world references from DIFFERENT aesthetic families — one's type discipline + the other's color attitude — instead of designing inside one family.
- User-provided references (screenshots, sites, brand names) are the strongest signal you'll get: extract tokens from them — palette attitude, type discipline, density, mood — and state in the plan what you take from each and what you deliberately leave. Two+ references → remix; a single reference → never clone it wholesale, name your deliberate departure.

## 2. Generic check (kill the defaults)
AI-generated design clusters around known looks. If any part of your plan matches, you didn't choose it — revise that part and say what changed:
- cream/off-white bg + high-contrast serif + terracotta accent
- near-black bg + single acid-green/vermilion accent
- broadsheet: hairline rules, zero radius, dense newspaper columns
- purple/blue gradient hero, glassmorphism cards, Inter-for-everything
- hero = big number + small label + gradient accent
- numbered markers (01/02/03) when content is not actually a sequence
- decorative dividers/eyebrows/labels that encode nothing true about the content
- emoji as section markers · everything centered · rounded-lg on everything · accent bar/rail on rounded cards · Space Grotesk as the "safe" face
- an accent line/rule under a title — separate with whitespace or a background shift instead
- 3-column feature grid as the default landing structure · blinking status dots · a stock icon on every bullet · filler sections nobody asked for ("Our values", "Team") · dataviz-as-decoration (numbers that mean nothing)
Test: would this exact plan come out for a DIFFERENT brief? If yes, it's a default.
Swap test: if your palette dropped into a completely different project would still "work", the choices aren't specific enough yet.
Clearance is written, not silent (measured: models read this list and still ship cream+serif or 01/02/03): in the plan, name the ONE default look your palette/type sits closest to and state in one line how it diverges. A structural device (numbering, eyebrows, dividers) gets one line saying what true fact of the content it encodes — no line, cut it.
Timidity is also a default: if after revision the plan takes no risk at all, it fails this check too — not taking a risk is itself a risk. Exactly one justified risk survives (editorial treatment; utilitarian pages pass on craft, not boldness).
Exception: the brief's own words always win — if the user asked for one of these looks, follow it exactly.

## 3. Build
- Fill the token skeleton in [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md) from the plan. EVERY color/size/space in the CSS traces to a token. No magic values.
- Obey the objective floors table there (scale ratios, line length, contrast, spacing steps, radius discipline).
- CSS specificity care: type-based selectors (`.section`) and element selectors silently cancel each other's paddings/margins between sections — keep one consistent selector level.
- Space siblings with flex/grid `gap`, not per-element margins that collapse or double. Wide content (tables, code, diagrams) gets its own `overflow-x: auto` container. `tabular-nums` where digits align; `text-wrap: balance` on headings.
- UI-not-document: a dashboard/tool is scanned and operated, not read — summary before detail; encode state in form (pill, chip, severity stripe), not numbers alone; semantic good/warning/critical colors stay separate from the accent and don't count as it; what's interactive must look interactive.
- Any chart, stat tile, or data display → obey the charts section in DESIGN-SYSTEM.md. Form first, color last, never a dual axis.
- Never fabricate product imagery with CSS/SVG (phone silhouettes, fake screenshots, 3D mockups) — one of the strongest slop signals. Insert a dimensioned placeholder instead: `[hero image: product in browser, 1400×900]`.
- Generative/decorative graphics: Canvas or WebGL, not hand-authored long SVG path data — and always seeded randomness, so a good result is reproducible and iterable.
- Multi-section surfaces (long pages, decks): vary layout archetypes — never the same section layout twice back-to-back (columns → cards → callout, not cards ×4).
- Motion: one orchestrated moment beats scattered effects. Extra animation is a top AI tell. Respect `prefers-reduced-motion`. When unsure, less.
- Match complexity to the vision: maximalist direction → elaborate execution; minimal direction → precision in spacing, type, detail.

## 4. Copy (words are design material)
- Name things by what the user controls, never by how the system is built (notifications, not webhook config).
- A control says exactly what happens ("Save changes", not "Submit"); an action keeps the same name through the whole flow.
- Errors: what went wrong + how to fix it, no apology, never vague. Empty states invite an action.
- Plain verbs, sentence case, no filler, specific beats clever. One job per element.
- Build with the brief's real content and subject matter throughout — write real copy, never lorem ipsum. Templated copy makes a design feel as generic as templated visuals.

## 5. Critique pass (mandatory before done)
- Render/screenshot and LOOK at it if the environment allows — a picture is worth 1000 tokens.
- If you CANNOT render: run the overflow discipline checks in DESIGN-SYSTEM.md §5 against the code — mobile right-edge clipping is the measured #1 shipped defect.
- Chanel rule: remove one accessory — cut the least-justified decorative element.
- Refinement only increases cohesion of what exists: no new graphics, no new filters, no font swaps at this stage — piling on decoration is the classic revision failure.
- Mechanical defect scan: overlapping elements, text overflow, misaligned rules, low-contrast icons, leftover placeholders (`grep -iE 'lorem|xxxx|TODO'`). Complete at least one fix-and-re-check cycle; you've been staring at the code and will see what you expect, not what's there.
- Squint test on the render: blurred, the section hierarchy must still read and nothing may jump forward — if borders are the first thing you see, they're too strong.
- Quality floor (silent — build to it, don't announce it):
  - [ ] responsive to mobile, no horizontal body scroll
  - [ ] visible keyboard focus on every interactive element
  - [ ] contrast: body ≥4.5:1, large text ≥3:1 (formula in DESIGN-SYSTEM.md)
  - [ ] line length 45-75ch; all values from tokens
  - [ ] reduced-motion respected; hover states exist
- Re-run the step-2 generic check against the BUILT page, not the plan.
- On weak-model risk of drift: if the diff is large, spawn one fresh-context subagent with ONLY the brief + a screenshot/HTML, asked "which parts look AI-templated?"; fix what it confirms.
- Log one line — palette family + type pairing + depth strategy + scale ratio + signature — to memory/project notes if available. Same project later → reuse it for consistency; a NEW brief must not repeat it: human designers remember what they've tried and reach for something new.

## Never
Write CSS before step 1 · use a font/palette you didn't pick for THIS brief · spend boldness twice — or zero times · decorate structure that encodes nothing · gradient-as-personality · same pairing as your previous design · lorem ipsum · ship without the critique pass
