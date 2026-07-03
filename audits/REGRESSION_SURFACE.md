# Regression Surface Audit

## Purpose

Find regression-prone complexity hotspots before they break: files and modules containing logic that spans multiple subsystem boundaries or overlaps responsibilities. This audit surfaces fragile fallback ladders, duplicated state/identity aliases, overly aggressive error paths (e.g. general catches that trigger session erasure or logout), and loose contract boundaries. It aims to prevent recurring regressions by defining extraction seams and prescribing targeted regression test scenarios.

Read-only by default.

## Mode: Read-Only

## When to run

- After complex refactors, auth updates, integration of overlapping subsystems, or when regressions occur.
- When a simple fix (like an OTP redirect change) triggers unintended side effects (like state erasure).
- Before refactoring integration-heavy modules or auth subsystems.

**Model tier**: `default`

## Time estimate

30–60 minutes for a typical mid-size codebase. Focuses on modules handling auth, session, router, cache, retry, or integration logic.

## Output

`docs/reports/REGRESSION_SURFACE_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery

Identify modules and files handling session state, client-side persistence, route guarding, or integration boundaries.

```bash
# Locate auth, session, cache, and storage files
find . -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.go' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  | grep -iE 'auth|session|cache|storage|guard|retry|client|api' | head -40

# Scan for state-storage and fallback indicators in source files
grep -rnE '(localStorage|sessionStorage|cookie|token|session_id|fleetcrewSessionId)' \
  --include='*.js' --include='*.ts' --include='*.tsx' --include='*.astro' --include='*.go' \
  -not -path '*/node_modules/*' . | head -40
```

Record:
- Key files handling state management, authentication, routing, or third-party integration.
- Storage/session keys used across the codebase.
- Any known integration boundaries or third-party API clients.

---

## Phase 1: Complexity & Churn Hotspots

Goal: Identify files that combine high logical complexity (many conditional branches) with high change velocity (churn in the last 6 months).

```bash
# Files changed most in the last 6 months
git log --since='6 months ago' --name-only --pretty=format: \
  | grep -vE '^$|node_modules|dist|build|\.lock$|package-lock' \
  | sort | uniq -c | sort -rn | head -20

# Count complexity indicators (e.g. if/else, switch, try/catch) in candidate files
# Replace FILE with a candidate from above
FILE="projects/vostego/site/public/assets/js/auth.js"
if [ -f "$FILE" ]; then
  grep -cE '(\bif\b|\belse\b|\bswitch\b|\btry\b|\bcatch\b)' "$FILE"
fi
```

Record per candidate:
- Commit count and author count in the window.
- Rough count of conditional/exception branches.
- Whether it acts as an integration hub for other modules.

---

## Phase 2: Overlapping State & Fallback Ladders

Goal: Detect files that mix multiple similar state models, use fallback ladders (`x || y || z`) for critical identity/session data, or maintain duplicate data aliases.

Search candidates for:
- Duplicated keys in local storage or cookies (e.g., `sessionId` and `fleetcrewSessionId`).
- Conditional fallbacks that resolve credentials from multiple places inconsistently.
- In-memory state variables that cache or wrap storage variables with potential drift.

```bash
# Search for fallback patterns in assignments
grep -rnE '(\bconst\b|\blet\b|\bvar\b)\s+\w+\s*=\s*\w+(\.\w+)?\s*\|\|' \
  --include='*.js' --include='*.ts' --include='*.tsx' --include='*.astro' . | head -30
```

Record:
- Target files/lines where fallbacks occur.
- Risk of state drift or split-brain behavior (e.g. token expired but session_id is active).

---

## Phase 3: Contract Fragility & Loose Boundaries

Goal: Audit API and module boundaries for undocumented types, loose schemas, or missing error models that break easily when the provider shifts behavior.

Look for:
- API response parsing that assumes specific fields exist without default fallbacks.
- Implicit headers or query params that are parsed/constructed manually in multiple places rather than centralizing.
- Lack of schema validation (e.g., JSON parsing without validation or Go unmarshalling into `map[string]any` without safety assertions).

Record:
- File and line of loose boundaries.
- Failure modes if API payload shifts or structure is partial.

---

## Phase 4: Broad Catches & Aggressive Side-Effects

Goal: Identify overly broad `catch` blocks or general error handlers that trigger aggressive side effects like erasing state or logging out the user when a gentler recovery path is available.

```bash
# Locate try/catch blocks that invoke clear/logout actions
grep -rnA 5 -E '\bcatch\b' \
  --include='*.js' --include='*.ts' --include='*.tsx' --include='*.astro' . \
  | grep -iE 'logout|clear|removeItem|removeCookie|destroy' -B 2 -A 3 | head -30
```

Record:
- Broad catch/error paths that trigger global state clearing or logouts.
- Rationale for why they are too aggressive (e.g. passive profile fetch failing shouldn't drop the active session).

---

## Phase 5: Refactoring Seams & Regression Scenarios

For each finding, propose:
1. **Extraction Seams**: How to split the file or isolate the fragile logic (e.g., extracting session management into a dedicated `SessionStore` class with clear tests).
2. **Regression Scenarios**: Targeted test cases (Playwright e2e, unit testing with mocks, or contract assertions) that must be added to verify correctness and prevent regression.

---

## Severity rubric (this audit)

| Severity | Criteria | Action |
|----------|----------|--------|
| **P0** | High-risk pattern currently causing user-facing failure, session state loss, or immediate regression | Fix immediately |
| **P1** | Overlapping aliases, duplicated state models, or fragile error handlers lacking test coverage, but not currently failing | Fix this sprint |
| **P2** | Complex fallback ladders, loose contract boundaries, or high-churn module with minor fragility | Backlog |
| **P3** | Minor stylistic issues or undocumented boundaries with low churn | Delete or document |

---

## Report template

```markdown
# Regression Surface Audit Report — <YYYY-MM-DD>

## Severity rubric (this audit)
- **P0**: High-risk pattern currently causing user-facing failure, session state loss, or immediate regression.
- **P1**: Overlapping aliases, duplicated state models, or fragile error handlers lacking test coverage, but not currently failing.
- **P2**: Complex fallback ladders, loose contract boundaries, or high-churn module with minor fragility.
- **P3**: Minor stylistic issues or undocumented boundaries with low churn.

## Summary
- Files analyzed: X
- Findings: X (P0: X, P1: X, P2: X, P3: X)
- Phases run: 0, 1, 2, 3, 4, 5

## P0 — High-Risk Failures
| # | Issue | Location | Impact | Suggested Fix |
|---|-------|----------|--------|---------------|
| 1 | ... | path:line | ... | ... |

## P1 — Fragile Patterns & Test Gaps
| # | Issue | Location | Impact | Suggested Fix |
|---|-------|----------|--------|---------------|
| 1 | ... | path:line | ... | ... |

## P2 — Complex Fallbacks & Boundaries
| # | Issue | Location | Impact | Suggested Fix |
|---|-------|----------|--------|---------------|
| 1 | ... | path:line | ... | ... |

## Seam Proposals & Regression Scenarios

### [Component/File Name]
- **Proposed Seam**: [e.g. Extract credentials fallback logic into `AuthHeaders` constructor]
- **Regression Test Scenario**: [e.g. Mock partial response (only token, no session_id) and assert client retains login status]

## Patterns observed
1–3 paragraph synthesis of root causes, focusing on how complexity crept in and why regressions recur.

## Next steps

Suggested invocations to act on this report:

**Resolve all actionable findings:**

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME against the
report at <THIS_REPORT_PATH>.
```

**Re-run this audit after resolution to verify clean state:**

```
[same invocation that produced this report]
```
```
