# UX Design Audit (DESIGN.md compliance)

## Purpose

Audit the rendered UI and the CSS/component code against the project's `DESIGN.md` (the design-token source of truth). Find hardcoded values that should be tokens, color and spacing drift, motion timing inconsistencies, dark-mode gaps, and accessibility regressions.

`DESIGN.md` is the contract. This audit verifies the implementation honors it.

## Prerequisite

This audit requires `DESIGN.md` at the project root (see [google-labs-code/design.md spec](https://github.com/google-labs-code/design.md)). If absent, generate it first — see the bootstrap prompt in this directory's README.

## When to run

Before any release that ships visual changes, after a theme/token update, quarterly otherwise. Read-only on the codebase. Phases 5–8 use a running app or screenshots.

## Time estimate

- **Quick** (45 min): Phases 1–3 (token compliance + colors)
- **Standard** (90 min): Phases 1–6
- **Deep** (120+ min): All phases including accessibility and dark mode

## Output

`docs/reports/UX_DESIGN_AUDIT_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery

```bash
# DESIGN.md present?
ls DESIGN.md design.md 2>/dev/null

# Stylesheet locations
find . \( -name '*.css' -o -name '*.scss' -o -name '*.sass' -o -name '*.less' \
  -o -name '*.styl' -o -name '*.module.css' \) \
  -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*' \
  -not -name '*.min.css' | head -30

# Inline styles / styled-components / Tailwind
grep -rln --include='*.tsx' --include='*.jsx' --include='*.vue' \
  -E 'styled\.|css`|className=' . | grep -v node_modules | head -10

ls tailwind.config.* 2>/dev/null
```

Record: where DESIGN.md lives, where styles live (CSS files, CSS-in-JS, Tailwind), whether the project has a `:root` token block.

---

## Phase 1: Extract DESIGN.md tokens

Parse the YAML frontmatter of `DESIGN.md`. Build a reference of:

- **Colors** (with hex values)
- **Spacing scale** (e.g., 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 80 / 96 px)
- **Border radii** (with values)
- **Font families** (with names)
- **Font sizes** (with values)
- **Motion durations** (e.g., 150ms / 260ms / 420ms)
- **Motion easings** (cubic-bezier strings or names)
- **Shadows / elevation** (with values)
- **Breakpoints** (with values)

This list is the **canonical set**. Anything in the codebase that doesn't match is a drift candidate.

---

## Phase 2: CSS Variable Compliance

Verify the codebase exposes the tokens as CSS variables (typical pattern: `:root { --color-primary: #...; }`).

```bash
# :root block
grep -rEn -A 200 ':root\s*\{' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -E '^\s*--[a-z][a-z0-9-]+\s*:' | head -100
```

Cross-check against Phase 1: every token in DESIGN.md should have a corresponding CSS variable. Missing variables = the design system is implemented inconsistently.

---

## Phase 3: Hardcoded Values

### 3.1 Hex colors outside `:root`

```bash
grep -rEn '#[0-9a-fA-F]{3,8}\b' \
  $(find . -name '*.css' -o -name '*.scss' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -v ':root' | grep -v '/\*' | grep -v 'linear-gradient\|background-image' | head -100
```

### 3.2 rgb()/hsl() outside `:root`

```bash
grep -rEn 'rgb\(|rgba\(|hsl\(|hsla\(' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -v ':root' | grep -v 'var(' | head -50
```

### 3.3 Hardcoded spacing

```bash
# px values for padding/margin/gap not using a var
grep -rEn -E '(padding|margin|gap)\s*:\s*[0-9]+(\.[0-9]+)?(px|rem|em)' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -v 'var(' | grep -v ':root' | head -100
```

Cross-check each value against the DESIGN.md spacing scale. Off-scale values (e.g., `7px` when the scale is `4/8/12`) are P1 even if they look fine.

### 3.4 Hardcoded radii

```bash
grep -rEn 'border-radius\s*:' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -v 'var(' | grep -v ':root' | grep -v '9999px\|50%\|inherit' | head -50
```

### 3.5 Hardcoded transitions / motion

```bash
grep -rEn 'transition\s*:|animation-duration\s*:' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -v 'var(' | grep -v ':root' | head -50

# Off-scale durations
grep -rEhn -oE '[0-9]+m?s' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | sort -u
```

Compare durations against the canonical motion scale from DESIGN.md.

### 3.6 Hardcoded font families

```bash
grep -rEn 'font-family\s*:' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -v 'var(' | grep -v ':root' | grep -v 'inherit' | head -30
```

### 3.7 Hardcoded font sizes

```bash
grep -rEn 'font-size\s*:\s*[0-9]' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | grep -v 'var(' | grep -v ':root' | grep -v 'clamp(' | head -50
```

### 3.8 Inline styles / Tailwind arbitrary values

```bash
# Inline style props
grep -rEn 'style=\{\{' \
  --include='*.tsx' --include='*.jsx' . | grep -v node_modules | head -30

# Tailwind arbitrary values that bypass the design system
grep -rEn '\[#[0-9a-fA-F]+\]|\[[0-9]+px\]' \
  --include='*.tsx' --include='*.jsx' --include='*.html' . | grep -v node_modules | head -50
```

---

## Phase 4: Color Fidelity

For each documented color in DESIGN.md, search the codebase for **near-matches** (similar but not identical hex). These are the most insidious drift — visually almost-right, programmatically wrong.

```bash
# For a target color #5f6ad3, find similar hexes
# (Manual — eyeball hex distance. Or use a script that computes ΔE.)
grep -rEn '#5[ef][0-9a-fA-F]{4}' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null
```

For each near-miss: is it the documented color (drift to fix) or a documented neighbor (acceptable)?

---

## Phase 5: Motion / Interaction (live)

Requires running app. With a browser DevTools or Playwright:

- Hover/focus/active transitions: do they use only the documented durations?
- Modal/drawer/menu open/close: durations match DESIGN.md?
- Loading skeletons, toasts, page transitions: in the documented motion vocabulary?

Record any animation that uses a duration not in the canonical scale.

---

## Phase 6: Responsive Behavior (live)

At each breakpoint defined in DESIGN.md (typical: 390 / 768 / 1280 / 1920):

- Layout integrity: no clipping, overlapping, or scroll traps
- Token usage: spacing scale still respected (a tighter mobile layout shouldn't introduce ad-hoc 6px gaps)
- Typography: clamp() / fluid type works as documented

Screenshot each breakpoint for the report.

---

## Phase 7: Accessibility

- **Touch targets**: ≥44×44 px (or per DESIGN.md spec)
- **Focus rings**: visible on every interactive element; uses the documented focus token
- **Contrast**: text passes WCAG AA against its background — check both light and dark themes
- **Reduced motion**: `@media (prefers-reduced-motion: reduce)` honored?

```bash
grep -rEn 'prefers-reduced-motion' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null
```

---

## Phase 8: Dark Mode Completeness

If DESIGN.md specifies a dark theme:

- Every documented dark-mode token has a CSS variable
- No component is missing dark-mode rules (heuristic: components that use light-only colors directly)
- No hardcoded white/black backgrounds

```bash
# Components using literal white/black
grep -rEn -E '(background|color)\s*:\s*(white|black|#fff|#000|#ffffff|#000000)\b' \
  $(find . -name '*.css' -not -path '*/node_modules/*' -not -name '*.min.css') 2>/dev/null \
  | head -50
```

---

## Severity rubric

| Severity | Criteria |
|----------|----------|
| **P0** | Visually wrong: contrast failure, broken layout at a documented breakpoint, missing focus ring on a primary action |
| **P1** | Hardcoded value visually drifts from DESIGN.md token (`#5566cc` instead of `#5f6ad3`); off-scale spacing/duration |
| **P2** | Hardcoded value matches the token numerically but doesn't reference it (fragile to theme change) |
| **P3** | Value not represented in DESIGN.md at all — needs a token defined or value removed |

---

## Report template

```markdown
# UX Design Audit — <DATE>

## Summary
- Stylesheets reviewed: X
- Findings: X (P0: X, P1: X, P2: X, P3: X)
- Phases run: ...

## Token coverage
| Token category | DESIGN.md tokens | CSS vars defined | Used via var() | Hardcoded usages |
|---|---|---|---|---|
| Colors | X | X | X | X |
| Spacing | X | X | X | X |
| Radii | X | X | X | X |
| Motion | X | X | X | X |
| Typography | X | X | X | X |

## P0 — Visually wrong
| Location | Issue | Suggested fix |
|---|---|---|

## P1 — Drift from DESIGN.md
| Location | Hardcoded value | Expected token | Action |
|---|---|---|---|

## P2 — Fragile (not using var)
...

## P3 — Undocumented values
...

## Live screenshots (if Phases 5–8 run)
- 390px:  <link or path>
- 768px:  ...
- 1280px: ...
- Dark mode: ...

## Recommendations
1. ...
```
