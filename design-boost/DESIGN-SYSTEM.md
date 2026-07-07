# Design System Template

Fill this per brief from the step-1 plan. Filled values are disposable — never reuse them on the next brief. Every value in the final CSS must trace back to a token here.

## 1. Token skeleton

```css
:root {
  /* color — from the plan, ONE accent */
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
| Spacing | scale steps only; gap inside a group < gap between groups (≥2 steps apart) |
| Content width | prose 65-72ch · marketing 1100-1200px · dashboard fluid + 24-32px gutters |
| Section rhythm | marketing 96-160px vertical · app/dashboard 48-64px |
| Targets | interactive elements ≥40px tall; visible `:focus-visible` ring everywhere |
| Radius | ONE family: 0 (sharp/editorial) · 4-6px (technical) · 10-16px (soft/friendly). Pills only as a deliberate accent |
| Elevation | pick borders OR shadows as the dominant separator; a card never needs both |

Contrast check: ratio = (L1 + 0.05) / (L2 + 0.05) with L = WCAG relative luminance. No calculator at hand → demand an obviously-large lightness gap and verify visually on the render.

## 3. Direction vectors (starting points, NOT defaults)

Pick the mood from the subject, then choose concrete faces fresh — never the same pairing twice in a row.

- **Editorial/literary** — high-contrast or wedge serif display + humanist sans body; generous measure
- **Technical/precision** — tight grotesque display + neutral sans body + mono for data
- **Warm/human** — soft serif or rounded sans display + open humanist body; tactile colors
- **Luxury/quiet** — didone or refined serif display, muted palette, oversized whitespace, hairline accents
- **Brutalist/raw** — oversized grotesque, stark contrast, hard edges, system-font honesty
- **Playful** — chunky display with personality, saturated accent, springy motion (one moment)

## 4. CSP-restricted contexts (Claude artifacts: no external fonts/assets)

External fonts are blocked — use characterful SYSTEM stacks, not bare `system-ui`:

- Serif display: `Charter, 'Iowan Old Style', 'Palatino Linotype', Georgia, serif`
- Grotesque display: `'Helvetica Neue', 'Segoe UI', Arial, sans-serif` (push weight/size/tracking hard)
- Body sans: `system-ui, 'Segoe UI', Roboto, sans-serif`
- Mono/data: `ui-monospace, 'Cascadia Code', Consolas, monospace`

When font choice is constrained, create contrast with weight jumps (400↔700+), size jumps (≥2 scale steps), case, and spacing instead.

## 5. Motion system

- ONE orchestrated moment (page-load stagger OR a single scroll reveal) > scattered effects everywhere.
- Entrances: fade + translateY(8-16px), durations from tokens, stagger siblings 40-80ms.
- Hover: color/underline/1-2px lift at `--t-fast`. Nothing bounces unless the direction is playful.
- Always:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation: none !important; transition: none !important; }
}
```

## 6. Dark/light (when both are required)

- Define tokens twice: `@media (prefers-color-scheme: dark)` as default signal + `[data-theme]` overrides that win in both directions.
- Dark is not inversion: desaturate accents slightly, lift `--surface` above `--bg`, replace shadows with borders, dim images if needed.
