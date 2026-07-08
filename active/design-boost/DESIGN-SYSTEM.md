# Design System Template

Fill this per brief from the step-1 plan. Filled values are disposable — never reuse them on the next brief. Every value in the final CSS must trace back to a token here.

## 1. Token skeleton

```css
:root {
  /* color — from the plan, ONE accent.
     Neutrals are chosen, not defaulted: tint every grey (bg/muted/border)
     slightly toward the accent hue — a pure mid-grey reads unconsidered. */
  --bg: ; --surface: ; --text: ; --muted: ;
  --accent: ; --accent-ink: ; /* accent-ink = text ON accent, check contrast */
  --border: ;

  /* type */
  --font-display: ; --font-body: ; --font-utility: ; /* optional */
  --scale: 1.25;            /* ratio table below */
  --text-sm: calc(1rem / var(--scale));
  --text-base: 1rem; /* 16-18px */
  --text-lg: calc(1rem * var(--scale));
  --text-xl: calc(var(--text-lg) * var(--scale));
  --text-2xl: calc(var(--text-xl) * var(--scale));
  --text-hero: calc(var(--text-2xl) * var(--scale) * var(--scale));

  /* space — 4px base, these steps ONLY */
  --s1: 4px; --s2: 8px; --s3: 12px; --s4: 16px; --s6: 24px;
  --s8: 32px; --s12: 48px; --s16: 64px; --s24: 96px; --s32: 128px;

  /* shape & elevation — ONE personality (see floors) */
  --radius: ;
  --shadow: ;

  /* motion */
  --t-fast: 150ms; --t-base: 250ms; --t-slow: 400ms;
  --ease: cubic-bezier(0.2, 0, 0, 1);
}
```

## 2. Objective floors (non-negotiable numbers)

| Axis | Rule |
|---|---|
| Scale ratio | 1.2 dense/data-UI · 1.25 default · 1.333 editorial · 1.5+ poster/marketing hero |
| Body size | 16-18px; captions/labels never below 13px |
| Line-height | display 1.05-1.15 · headings 1.2-1.3 · body 1.5-1.7 |
| Letter-spacing | display -0.01~-0.03em · body 0 · ALL-CAPS labels +0.05~0.12em |
| Line length | body 45-75ch (sweet spot 65ch); never full-bleed paragraphs |
| Contrast | body vs bg ≥4.5:1 · large/bold text ≥3:1 · also check accent-ink on accent |
| Color weight | ONE color carries 60-70% of visual weight, 1-2 supporting tones, one sharp accent — never distribute colors equally |
| Alignment | body text and lists left-aligned, always; center titles only |
| Spacing | scale steps only; gap inside a group < gap between groups (≥2 steps apart) |
| Content width | prose 65-72ch · marketing 1100-1200px · dashboard fluid + 24-32px gutters |
| Section rhythm | marketing 96-160px vertical · app/dashboard 48-64px |
| Targets | interactive elements ≥40px tall; visible `:focus-visible` ring everywhere |
| Radius | ONE family: 0 (sharp/editorial) · 4-6px (technical) · 10-16px (soft/friendly). Pills only as a deliberate accent. Nested rounding: outer = inner + padding |
| Depth | declare ONE strategy before coding — borders-only · subtle shadows · layered shadows · surface-tint — and never mix; a card never needs border AND shadow |
| Dense-UI hierarchy | when scale steps don't fit, build 3 tiers at ONE size via weight (600/500/400) + ink tiers — never size alone |
| Media floors | slide decks ≥24px body at 1080p · print ≥12pt · no sub-1px hairlines on mobile |

Contrast check: ratio = (L1 + 0.05) / (L2 + 0.05) with L = WCAG relative luminance. No calculator at hand → demand an obviously-large lightness gap and verify visually on the render.

Product-UI surface semantics & polish:
- Inputs sit slightly darker than their surroundings (inset = "type here"); sidebars use the canvas background + a hairline border, never a different color.
- `text-wrap: balance` on headings, `text-wrap: pretty` on body; `tabular-nums` on dynamic numbers.
- Icon+text optical alignment: icon-side padding ≈ text-side − 2px. Image outlines in pure `rgba(0,0,0,.1)` / `rgba(255,255,255,.1)`, never tinted.

## 3. Direction vectors (starting points, NOT defaults)

Pick the mood from the subject, then choose concrete faces fresh — never the same pairing twice in a row.

- **Editorial/literary** — high-contrast or wedge serif display + humanist sans body; generous measure
- **Technical/precision** — tight grotesque display + neutral sans body + mono for data
- **Warm/human** — soft serif or rounded sans display + open humanist body; tactile colors
- **Luxury/quiet** — didone or refined serif display, muted palette, oversized whitespace, hairline accents
- **Brutalist/raw** — oversized grotesque, stark contrast, hard edges, system-font honesty
- **Playful** — chunky display with personality, saturated accent, springy motion (one moment)

## 4. CSP-restricted contexts (Claude artifacts: no external fonts/assets)

External fonts are blocked — never link a font CDN there; it fails silently to a fallback. Either inline the face as a `@font-face` data URI (when the type IS the design and you have the encoded face) or use characterful SYSTEM stacks, not bare `system-ui`:

- Serif display: `Charter, 'Iowan Old Style', 'Palatino Linotype', Georgia, serif`
- Grotesque display: `'Helvetica Neue', 'Segoe UI', Arial, sans-serif` (push weight/size/tracking hard)
- Body sans: `system-ui, 'Segoe UI', Roboto, sans-serif`
- Mono/data: `ui-monospace, 'Cascadia Code', Consolas, monospace`

When font choice is constrained, create contrast with weight jumps (400↔700+), size jumps (≥2 scale steps), case, and spacing instead.

## 5. Overflow discipline (measured failure mode — mobile clipping)

Benchmarked models ship pages whose text/grids clip off the right edge at 390px. These are static code rules — they work even when you cannot render:

- Display/hero type: `font-size: clamp(2rem, 7vw, <max>)` — never a fixed px size that only fits desktop.
- Long Korean/CJK or single-word headlines: add `overflow-wrap: break-word; word-break: keep-all` (CJK) on headings.
- Grid columns: `minmax(0, 1fr)`, never fixed px tracks that sum past 390px; grid/flex children need `min-width: 0`.
- Never `width: 100vw` (scrollbar overflow), never `white-space: nowrap` on content text, images always `max-width: 100%`.
- Letter-spacing on uppercase labels widens them — check the longest label at 390px.
- Mental test before done: at 390px, does any fixed width, min-width, or padding sum exceed 358px (390 - 2×16 gutter)? If yes it clips.

## 6. Charts & data (any chart, stat tile, or dashboard)

Form first, color LAST — most bad charts pick colors first.

- **Form**: match the data's job — magnitude→bar, change-over-time→line, identity→categorical, polarity→diverging, single headline→stat tile (sometimes the answer is NOT a chart).
- **One axis. Never a dual-axis chart** (two y-scales) — two measures of different scale → two charts or index to a common base. #1 chart mistake.
- **Categorical hues in fixed order, never cycled**; a 9th series folds into "Other". Color follows the entity, never its rank — filtering must not repaint survivors.
- **Sequential = one hue light→dark. Diverging = two hues + neutral gray midpoint.** Never rainbow; never a hue at the midpoint.
- **Status colors (good/warning/critical) are reserved** — never reused as "series 4", never color-alone (pair with icon/label), separate from the accent.
- **Marks**: thin bars with 4px rounded data-ends, 2px lines, ≥8px markers, 2px surface gap between stacked segments and adjacent fills.
- **Chrome recedes, data pops**: axis labels in muted ink, hairline gridlines, data labels outside bars — never library-default black axes.
- **Labels**: legend always present for ≥2 series (single series: the title names it); ≤4 series also direct-labeled; never a number on every point. Text wears text tokens, never the series color. `tabular-nums` on all figures.
- **Interaction**: HTML charts ship hover by default — crosshair+tooltip on line/area, per-mark tooltip on bar/dot; hit target bigger than the mark.
- CVD check: adjacent palette hues must survive colorblind simulation; when unsure add secondary encoding (texture/label), don't trust hue alone.

## 7. Motion system

- ONE orchestrated moment > scattered effects everywhere. Choose its placement from a deliberate menu — page-load sequence, scroll-triggered reveal, hover micro-interaction, or ambient atmosphere — wherever it serves the subject.
- Entrances: fade + translateY(8-16px), durations from tokens, stagger siblings 40-80ms. Never from `scale(0)` — start at `scale(0.95)` + fade. Never ease-in; exits faster and subtler than entrances; UI transitions <300ms.
- Gate by usage frequency: interactions repeated 100+ times a day (palette, shortcuts, list rows) get NO animation; occasional surfaces (modals, drawers) get standard motion; only rare moments get delight.
- Hover: color/underline/1-2px lift at `--t-fast`; press feedback `scale(0.97)` on `:active`. Nothing bounces unless the direction is playful.
- Always:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation: none !important; transition: none !important; }
}
```

## 8. Dark/light (when both are required)

- Define tokens twice: `@media (prefers-color-scheme: dark)` as default signal + `[data-theme]` overrides that win in both directions.
- Dark is not inversion: desaturate accents slightly, lift `--surface` above `--bg`, dim images if needed.
- Dark elevation is lightness, not shadow: step surfaces up quietly (+7% / +9% / +12% from base) and swap drop shadows for a 1px `rgba(255,255,255,.08)` ring — shadows are invisible on dark. Light mode elevates with shadow instead.
