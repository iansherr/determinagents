# Design Handoff Audit

## Purpose

Audit design handoff bundles (from Claude Design, Google Stitch, Figma, etc.) to extract a complete component manifest and identify integration gaps, without being misled by narrow or incomplete README.md files that often omit shell design elements like nav bars.

`DESIGN_HANDOFF_AUDIT.md` ensures a structurally complete view of the provided design components.

## Mode: Read-Only

## When to run

When receiving a new design handoff bundle, before starting implementation, or when components seem to be missing from the handoff overview.

**Model tier**: `default` — requires multi-step reasoning to diff manifests and classify files accurately.

## Output

`docs/reports/DESIGN_HANDOFF_AUDIT_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery

Identify the handoff directory path. Ask the user if it's not provided. Check if there is a README.md or similar overview document.

---

## Phase 1: Inventory before reading

Before opening any single file, run a full inventory of the handoff directory.

```bash
# Example for a React/Vue/HTML handoff
find /path/to/handoff -type f \( -name "*.html" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.vue" -o -name "*.css" -o -name "*.md" \)
```

Write the full list to a scratch file or hold it in context. Treat every file as in-scope until proven otherwise.

---

## Phase 2: Classify each file

Classify each file by what it contains, not by what the README says it is. For every file in the inventory, do a one-line classification:
- "tokens"
- "page render"
- "component source"
- "prose spec"
- "asset"

**Rules:**
- JSX and TSX files are component source = first-class spec, never "supporting imports."
- Render-style HTML files (with embedded fonts, base64 blobs) are downstream artifacts of the JSX. Read both and treat JSX as canonical when they disagree.

---

## Phase 3: Extract a component manifest

For each component-source file, search for class names, exported components, and CSS selectors. Build a **Canonical Manifest** (a flat list or JSON-compatible table). Example:
`web-extras.jsx` → `.site-header`, `.site-footer`, `.auth-modal`

This manifest is the spec — the README is just commentary on it. The manifest **MUST** be structured so `HARNESS_CREATOR.md` can iterate through it to verify every item's existence in the target codebase.

---

## Phase 4: Diff manifest against target codebase

For each component in the manifest, locate (or note the absence of) its counterpart in the target site/codebase.
- **Integration gap:** Anything in the manifest with no site counterpart.
- **Keep/Drift:** Anything in the site with no manifest counterpart is either pre-existing functionality to keep or drift to flag.

---

## Phase 5: Supporting context

Only now read the README and overview HTML — as supporting context for how the components fit together, never as the authoritative list of what exists.

---

## Anti-patterns (Do not do these)

- **Trusting the README's framing:** "Don't let the README's 'read this first' framing narrow your scope. The README is one author's view; the file tree is ground truth."
- **Preferring HTML over source:** "If a bundle contains both rendered HTML and component source (JSX/TSX), the component source is canonical. Rendered HTML loses interaction states, conditional logic, and prop variants."
- **Dismissing "imports":** "A file labeled 'imports' or 'supporting' often contains the actual primitives. Open it before deciding it's secondary."
- **Incomplete negative searches:** "When you say 'X doesn't exist in the handoff,' you must be able to cite the negative grep across the full inventory, not just the files the README pointed at."

**The meta-principle:** treat any human-written 'where to look' as a hint, not a boundary. A full directory walk + grep-based component manifest takes 5 minutes and would have caught the navbar on the first pass.

---

## Severity rubric

| Severity | Criteria |
|----------|----------|
| **P0** | Critical missing component (e.g., shell/nav bar) that breaks core app navigation or layout if ignored. |
| **P1** | Component missing from site that is clearly present in the handoff manifest. |
| **P2** | Incomplete implementation or divergence in component usage between handoff and site. |
| **P3** | README documentation discrepancy vs the actual file manifest. |

---

## Report template

Reports must also include the universal sections from `specs/FORMAT.md` — `## Severity rubric (this audit)` (copied verbatim from this doc's rubric) and `## Next steps` (paste-ready RESOLVE_FROM_REPORT invocation with this report's path filled in). Audit-specific structure below:

```markdown
# Design Handoff Audit — <DATE>

## Summary
- Handoff directory: <path>
- Files inventoried: X
- Components identified: X
- Integration gaps: X

## File Classification
| File | Classification | Notes |
|---|---|---|

## Component Manifest
| Component / Selector | Source File | Counterpart in Site | Status |
|---|---|---|---|

## Integration Gaps
| Component | Description | Recommended Action |
|---|---|---|

## Drift / Pre-existing Functionality
| Site Component | Status | Notes |
|---|---|---|

## Recommendations
1. ...
```
