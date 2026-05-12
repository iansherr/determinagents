# Pick Next Audit

## Purpose

Recommend which DeterminAgents audit to run next, based on what's stale, what the code has been doing, and the project's stated cadence. The user invokes this when they want to run *something* but don't have a plan — the audit picks for them.

Read-only. Writes no report unless `--log` is passed. The recommendation is rendered conversationally; the user runs the chosen audit as a separate invocation.

This is a meta-audit: it does not find issues in code. It triages the audit library against the project's recent history.

## When to run

- "I have an hour, what should I look at?"
- After a feature sprint, before declaring the release ready.
- Periodically (weekly / monthly), as a calibration check on which audits are being neglected.
- After joining a new project, to see which audits would surface the most signal first.

**Model tier**: `fast`

Rationale: this is classification and ranking over a small inventory, not multi-step reasoning. Cheap models do this well.

## Time estimate

5–15 minutes. The bulk is reading `docs/reports/` listings and `git log`.

## Output

Conversational. The agent prints a ranked recommendation table with one-line rationale per entry, plus a paste-ready invocation for the top pick.

If `--log` is passed, also write `docs/reports/PICK_NEXT_<YYYY-MM-DD>.md` for trend-tracking. Default is no log file — recommendations go stale fast and accumulating them is noise.

---

## Phase 0: Discovery

### 0.1 Inventory the audit library

```bash
ls "${DETERMINAGENTS_HOME:-$HOME/.determinagents}/audits/" | grep -E '^[A-Z_]+\.md$'
```

The set of read-only audits is the recommendation surface. The mutating audits (`RESOLVE_FROM_REPORT`, `STRUCTURAL_REFACTOR`, `SECURITY_HUNT`, `DATA_FLOW_VERIFY`, `TESTING_CREATOR`) are excluded from default ranking — they require a specific report or target as input, not a "run this next" recommendation.

Exception: if a recent read-only audit produced a P0/P1-heavy report and `RESOLVE_FROM_REPORT` hasn't run against it, surface that as a candidate (see Phase 4).

### 0.2 Inventory existing reports

```bash
ls -t docs/reports/*.md 2>/dev/null | head -50
```

Parse filenames. Reports follow `<AUDIT_NAME>_<YYYY-MM-DD>.md` (or `_<slug>_<YYYY-MM-DD>.md` for target-scoped audits). Group by audit name; take the most recent date per audit. Audits with no report ever = "never run" (highest staleness category).

### 0.3 Read AUDIT_CONTEXT cadence preferences

If `docs/determinagents/AUDIT_CONTEXT.md` has a `CADENCE` section, parse it. Each line maps an audit to a recommended interval (in days, or qualitative like "after major feature pushes", "anytime").

If no `CADENCE` section exists: every audit defaults to 90 days. Note this in the output so the user knows the default is in play.

### 0.4 Determine the analysis window

The git-history scan compares each audit's *last-run date* against commits since then. For never-run audits, use the last 90 days as the window (deeper history is rarely actionable).

---

## Phase 1: Staleness scan

For each read-only audit:

| Field | Source |
|---|---|
| `last_run` | Most recent `docs/reports/<AUDIT>_*.md` date, or `never` |
| `days_since` | `today - last_run`, or `∞` for never-run |
| `cadence_days` | From `CADENCE` section, or `90` default |
| `staleness_ratio` | `days_since / cadence_days` |

A `staleness_ratio` ≥ 1.0 means the audit is overdue per its cadence. Higher is more overdue.

Audits with `staleness_ratio < 0.5` are recent and ranked low regardless of surface-change signal — re-running a fresh audit rarely surfaces new findings.

---

## Phase 2: Surface-change scan

For each audit, find what's changed in its area-of-interest since its `last_run`. The mapping comes from each audit doc's Phase 0 (Discovery) patterns — read them, don't reinvent.

Approximate mapping (override per project via `CADENCE` extended entries):

| Audit | Watches |
|---|---|
| `SECURITY_PENTEST` | auth, session, JWT, crypto, route handlers, middleware |
| `STRUCTURAL_ENTROPY` | files crossing the project's p95 LOC line; high-churn files |
| `STUB_AND_COMPLETENESS` | new route handlers, new endpoints, frontend `fetch`/`axios` callsites |
| `ERROR_HANDLING` | `try/catch` additions, error UI, logging calls |
| `DATA_FLOW_TRACE` | UI → API → DB pathways for features added since last run |
| `TEST_GAPS` | new business logic without corresponding test files |
| `DOCS_DRIFT` | README, docs/, claims about endpoints/flags/commands |
| `UX_DESIGN_AUDIT` | CSS, design tokens, component styling |
| `RESOURCE_CAPACITY` | k8s manifests, Dockerfiles, infra config, dependency capacity settings |

```bash
# For each audit, run a scoped git log since its last_run date.
AUDIT="SECURITY_PENTEST"
SINCE="<last_run_date or 90 days ago>"
git log --since="$SINCE" --name-only --pretty=format: \
  | grep -E '(auth|session|jwt|crypto|middleware|/routes/|/handlers/)' \
  | sort -u | wc -l
```

Record per audit:
- `changed_paths_in_watch`: count of distinct files matching the audit's watch patterns
- `commit_count_in_watch`: count of commits touching those files
- One-line evidence string (e.g., `"12 commits touched services/auth/** since 2026-02-14"`)

---

## Phase 3: Cadence overlay

Combine staleness and surface-change into a single rank. Use this scoring (the agent can adjust if `CADENCE` declares custom weights):

```
score = (staleness_ratio * 1.0) + (log(1 + changed_paths_in_watch) * 1.5)
```

Why the weights:
- Staleness alone over-recommends calendar-driven audits on quiet codebases.
- Surface-change alone over-recommends busy codebases for audits with shallow benefit.
- Surface-change is logarithmically dampened so 200 changes don't drown out a moderately-overdue audit with 20 changes.

Special-case escalations (override the score):

- **Unresolved P0 findings exist**: if any audit report has unresolved P0s (no `## Resolution` annotation marking them done), `RESOLVE_FROM_REPORT` for that report is the top recommendation. Always.
- **Never-run + high surface-change**: an audit that has never run *and* its watch patterns saw significant changes ranks above ordinary stale audits. The first run on a high-churn surface is usually the highest-yield run.
- **Cadence overdue by 2x+**: any audit ≥ 2.0 staleness-ratio with non-trivial surface-change is elevated regardless of score — the cadence preference is a stronger signal than raw arithmetic.

---

## Phase 4: Recommend

Output the top 3 ranked audits with a paste-ready invocation for the top pick.

### Output format

```
Project: <repo name>
Reports inventoried: <N>     |   Default cadence: 90d (from AUDIT_CONTEXT)
Window: <last_run> → today

Recommendation:

  1. SECURITY_PENTEST          score 3.4   [overdue 1.7x, 12 commits in auth/]
     Last run: 2026-02-14 (87 days ago). Cadence: 90d.
     Evidence: services/auth/middleware.go +147/-22; new /api/oauth/* routes.

  2. STRUCTURAL_ENTROPY        score 2.1   [never run, 8 high-churn files]
     Last run: never.
     Evidence: src/components/agent-workspace.tsx now 3,123 LOC, 89 commits/6mo.

  3. DOCS_DRIFT                score 1.4   [overdue 1.3x, README touched 6 times]
     Last run: 2026-03-04 (69 days ago). Cadence: 30d.
     Evidence: README.md +89/-34; INSTALL.md substantially rewritten.

Top pick — paste to run:

  /determinagents security
```

If a special-case escalation triggers, show it first with explanation:

```
Top pick (escalated): RESOLVE_FROM_REPORT
  Reason: docs/reports/SECURITY_PENTEST_2026-04-22.md has 3 unresolved P0s.
  Resolving outstanding P0s outranks any new audit run.

  /determinagents resolve --report=docs/reports/SECURITY_PENTEST_2026-04-22.md

Ordinary ranking (for reference, not recommended until P0s are resolved):
  ...
```

### Ambiguity surfacing

If two audits tie within ~10% of each other, show both at the top and let the user decide. Don't force a single pick when the signal is noisy.

If no audit scores above 0.5 (everything's fresh, codebase is quiet), say so:

```
No audit is overdue or showing meaningful surface change.
This codebase is well-maintained relative to the audit library.

If you want to run something anyway:
  - DOCS_DRIFT is the cheapest periodic re-check (5–15 min).
  - STRUCTURAL_ENTROPY has never run and would establish a baseline.
```

Don't fabricate urgency. The audit's value is honest recommendations, including "nothing's urgent."

---

## Severity rubric (this audit)

Not applicable — this audit produces recommendations, not findings. The audits it recommends have their own rubrics.

---

## Anti-patterns

- **Recommending whatever has the highest commit count.** Surface-change is one input; staleness and cadence preference modify it. A high-churn area that was audited yesterday rarely needs another run today.
- **Suppressing "nothing's urgent."** The honest signal is part of the value. If everything is fresh, say so — don't manufacture a recommendation.
- **Reading old reports for findings.** This audit doesn't care what *was* found, only when each audit *ran*. Findings are someone else's job; this is the dispatcher.
- **Recommending mutating audits without their prerequisites.** `RESOLVE`, `STRUCTURAL_REFACTOR`, `SECURITY_HUNT`, etc., need specific inputs. Only surface them when those inputs exist (unresolved findings, a specific report).
- **Re-recommending the same audit session over session.** If `PICK_NEXT` ran an hour ago and recommended `SECURITY_PENTEST`, and the user is back asking again, they probably already heard the answer. Read the most recent `PICK_NEXT_*.md` log (if `--log` was used) and acknowledge: "you ran this 1 hour ago and got X — do you want a fresh scan, or to pick from the previous ranking?"

---

## Composition with other docs

- **Inputs**: `docs/reports/*.md` (last-run inference), `git log` (surface change), `docs/determinagents/AUDIT_CONTEXT.md` `CADENCE` section.
- **Outputs**: a recommendation rendered to the user. The user invokes the recommended audit as a separate, normal session.
- **Follow-up**: any audit token from `INVOCATIONS.md` routing table.

The chain: **`/determinagents next` → recommendation → user picks → `/determinagents <recommended>`**. Each step is a fresh session.
