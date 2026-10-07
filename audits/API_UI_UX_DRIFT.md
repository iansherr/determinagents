# API / UI / UX Drift Audit

## Purpose

Find disconnects between backend capability and surfaced product experience:
missing UI for exposed endpoints, UI controls with no backend support, stale or
hardcoded labels/options, unreachable routes, and orphaned elements that no
longer map to a real feature.

This audit is portable. It discovers the project shape first and then builds a
canonical surface manifest from what the repo actually exposes.

## Mode: Read-Only

## When to run

Use this after a feature sprint, a backend expansion, or a navigation rewrite
when you want to know whether the UI still reflects the service contract.

**Model tier**: `default`

## Time estimate

Depends on app size and route count. Use `--phases=N,M` or `--max-time=Xm` to
scope tighter.

## Output

`docs/reports/API_UI_UX_DRIFT_<YYYY-MM-DD>.md`

---

## Phase 0: Discovery

Record the project shape and the surfaces you will compare.

```bash
# Frontend entry points
find . -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) \
  -not -path '*/node_modules/*' -not -path '*/dist/*' | head -50

# Backend route files / handlers
grep -rln --include='*.go' --include='*.ts' --include='*.js' --include='*.py' \
  -E '(router|Router)\.(get|post|put|delete|patch)|@(app|router|api|blueprint)\.route|\.HandleFunc|app\.(get|post|put|delete|patch)' \
  . 2>/dev/null | grep -v node_modules | head -50

# Docs and registries that describe intended surfaces
find . -path '*/docs/determinagents/*' -o -name 'DESIGN.md' -o -name 'AUDIT_CONTEXT.md' 2>/dev/null
```

Record:
- frontend route roots and nav shells
- backend route roots and admin-only handlers
- any feature registry, OpenAPI, or surface manifest
- any intentional aliases or redirects

---

## Phase 1: Build the canonical manifests

### 1.1 Frontend surface manifest

Inventory the UI from routes, nav structures, and visible controls:

- top-level routes
- nested tabs, drawers, and action menus
- empty states that imply missing capability
- literal labels, options, and constants that should come from data

### 1.2 Backend surface manifest

Inventory backend capability from route registrations, handlers, and service
methods:

- HTTP endpoints
- admin/ops helpers
- mutation paths that have no obvious UI trigger
- read-only endpoints that should be surfaced in dashboards or detail views

### 1.3 Hardcoded UI manifest

Build a list of UI literals that look like they should be data-driven:

- hardcoded menu items
- fixed tabs or category names
- status chips with inline string maps
- static counts, dates, or labels where backend data exists

The manifest is the ground truth. Diff the repo against the manifest instead of
spot-checking a few visible examples.

---

## Phase 2: Cross-reference

### 2.1 Backend-only capability

Surface backend routes that have no UI affordance:

- admin actions with no menu entry
- detail-page operations with no drawer/button
- reporting endpoints with no dashboard tile
- translation, validation, or approval flows that only exist in the service

### 2.2 UI-only capability

Surface UI elements that have no backend support:

- buttons that call nowhere
- routes that render static placeholders
- controls that only toggle local state
- forms whose submit path is missing or stubbed

### 2.3 Hardcoded value drift

Flag UI values that should be data-driven but are hardcoded:

- product names and entity labels
- role names, status mappings, and option lists
- counts, totals, and summary cards
- repeated copy that should come from a backend enum or registry

---

## Phase 3: Unused / orphaned surface hunt

Find:

- routes that nothing links to
- components exported but never rendered
- menu items that point at dead paths
- action handlers that are never reachable from the current nav
- backend helpers with no surfaced use case

Treat these as drift unless the repo documents them as intentionally hidden or
future-facing.

---

## Phase 4: Severity rubric

| Severity | Criteria |
|----------|----------|
| **P0** | User-facing flow is broken or a primary capability is missing from the UI entirely |
| **P1** | Important admin/ops capability exists in backend but not in UI, or UI shows stale/hardcoded data |
| **P2** | Feature exists but is awkwardly surfaced, duplicated, or only partially data-driven |
| **P3** | Dead route, orphaned component, or undocumented future-facing surface |

---

## Report template

Reports must also include the universal sections from `specs/FORMAT.md` —
`## Severity rubric (this audit)` and `## Next steps`.

```markdown
# API / UI / UX Drift Audit — <DATE>

## Summary
- Backend capabilities checked: X
- UI surfaces checked: X
- Hardcoded values found: X
- Orphaned surfaces found: X
- Total findings: X (P0: X, P1: X, P2: X, P3: X)

## P0 — Broken or missing primary flows
| Location | Drift | Suggested fix |
|---|---|---|

## P1 — Backend capability not surfaced
| Backend surface | Missing UI surface | Suggested fix |
|---|---|---|

## P2 — Fragile or partial surfacing
...

## P3 — Orphaned / dead surfaces
...

## Patterns observed
<2–3 paragraphs on repeated disconnects, naming drift, or hardcoded UX.>

## Recommendations
1. ...
2. ...
```
