# Automated Reporting Orchestrator

## Purpose

Create recurring, decision-ready reports from DeterminAgents audit outputs across real projects.

This spec is project-facing (unlike `specs/MAINTENANCE.md`, which is library-maintainer-only).
It standardizes how to collect signals, summarize risk, and trigger next actions without
auto-mutating code or infrastructure.

This is a synthesis harness, not an observability product. It does not scrape metrics,
store time series, send alerts, or replace dashboards. It reads existing audit reports
and explicitly supplied runtime snapshots, then produces a bounded digest.

Guiding principle: **operator clarity + execution harness beats clever prompt wording**.
The prompt should be plain and explicit; reliability comes from phase gates, evidence
contracts, and deterministic output shape.

**Model tier**: `reasoning` — this work is synthesis, trend comparison, and prioritization.

## Output

Primary report:

- `docs/reports/SYSTEM_DIGEST_<YYYY-MM-DD>.md`

Optional machine-readable companion:

- `docs/reports/signals/SYSTEM_DIGEST_<YYYY-MM-DD>.json`

JSON output should follow `specs/SIGNAL_SCHEMA.md`.

---

## Modes

Run one mode per invocation via `--mode=<baseline|trend|incident|change-review|portfolio>`.

### `baseline` (default)

Creates a current-state operational summary from available recent audit artifacts.

Use when:

- Standing up reporting for the first time
- You need a single current risk snapshot

### `trend`

Compares windows (for example 7d/30d) and reports directional movement.

Use when:

- You care about regression vs. a stable baseline
- You need "getting better vs. worse" decisions, not point-in-time status

### `incident`

High-cadence triage mode. Prioritizes active reliability/capacity/security risks and
suppresses lower-priority narrative.

Use when:

- There is an active production incident
- You need frequent roll-up updates (for example every 30-60 minutes)

### `change-review`

Post-deploy / post-infra-change impact report. Focuses on deltas since a specific change point.

Use when:

- After deploys, migrations, scaling, traffic-routing changes, or dependency upgrades

### `portfolio`

Cross-service rollup for multi-service repos/orgs. Produces one summary with per-service hot spots.

Use when:

- You operate multiple services and need shared prioritization

---

## Prompting contract (harness-first)

Write prompts as operating instructions, not persuasion.

Required characteristics:

1. **Bounded scope**: name exact input sources and time window.
2. **Deterministic outputs**: require fixed markdown sections plus JSON companion when possible.
3. **Evidence binding**: no recommendation unless tied to a concrete evidence row.
4. **Unknowns explicit**: if data is missing, output `unknown` with reason.
5. **Stop rule**: if a mutating follow-up is warranted, recommend invocation and stop.

Canonical operator prompt shape:

```text
Read only:
- docs/reports/*.md (window: <window>)
- docs/determinagents/AUDIT_CONTEXT.md (if present)
- runtime snapshot files explicitly provided

Mode: <baseline|trend|incident|change-review|portfolio>

Do:
1) Normalize signals into rows: metric, current, baseline, delta, threshold, status, evidence.
2) Rank top risks by impact × confidence.
3) Write:
   - docs/reports/SYSTEM_DIGEST_<YYYY-MM-DD>.md
   - docs/reports/signals/SYSTEM_DIGEST_<YYYY-MM-DD>.json (if possible)

Rules:
- Read-only. Do not mutate code or infrastructure.
- No recommendation without evidence.
- If evidence is missing, mark unknown and state what data is needed.
- Keep immediate actions to <=5.
```

---

## Inputs

Minimum input set (prefer explicit paths/flags):

1. Recent audit reports in `docs/reports/` (resource-capacity, security, data-flow, test-gaps, docs-drift)
2. Runtime snapshots from runbooks (CPU/memory/disk/network/error/latency)
3. Optional context overlay from `docs/determinagents/AUDIT_CONTEXT.md`

Optional flags:

- `--window=<7d|30d|custom>`
- `--since=<timestamp-or-release-tag>` (for `change-review`)
- `--services=<csv>` (for `portfolio`)
- `--max-findings=<N>`

---

## Intelligent generation strategies

Use strategy by mode and data quality, not one fixed template.

### Strategy 1: Threshold-driven (fast, low-noise)

Best for `incident` and noisy environments.

- Emit only when triggers cross explicit thresholds
- Keep output short and action-first

Starter triggers:

- 5xx sustained >1% for 15m+
- p95 latency >30% above baseline window
- sustained CPU or memory >70% during normal load windows
- repeated restart loops / timeout-connect failure bursts
- new unresolved P0/P1 security finding

### Strategy 2: Trend/regression-driven (planning)

Best for `trend` and weekly reviews.

- Compare against previous windows
- Highlight deterioration/improvement and confidence

### Strategy 3: Topology-aware synthesis (complex systems)

Best for `portfolio` or systems with shared dependencies.

- Group findings by shared blast radius (edge, DB, queue, cache)
- Surface coupling risks (one dependency causing multi-service impact)

### Strategy 4: Change-point analysis (post-deploy safety)

Best for `change-review`.

- Anchor before/after to deploy or infra-change timestamp
- Attribute likely impact with explicit confidence and unknowns

---

## Harness gates

Treat these as required phase checks around generation.

### Phase 0: Preflight

- Validate mode and required flags.
- Validate input presence (at least one usable report/snapshot source).
- Validate time window or `--since` marker format when supplied.

If preflight fails: stop and report exact missing prerequisites.

### Phase 1: Normalize

Map source findings to a normalized signal schema:

- `signal_id`
- `category` (`reliability|capacity|dependency|security|cost|drift`)
- `metric`
- `current_value`
- `baseline_value` (or `unknown`)
- `delta`
- `threshold`
- `status` (`ok|watch|triggered|unknown`)
- `evidence_ref` (file:line or metric origin)
- `confidence` (`high|medium|low`)

Use `specs/SIGNAL_SCHEMA.md` as the canonical contract for field names,
required keys, and validation rules.

### Phase 2: Score and rank

- Rank by impact first, then confidence.
- Promote cross-service/shared-dependency blast radius in `portfolio` mode.
- Cap immediate actions to highest-leverage items.

### Phase 3: Emit and lint

Before finalizing report, enforce:

- Every recommendation references at least one `signal_id`.
- Every risk has urgency and owner.
- Every causal claim includes confidence and unknowns.
- Stable section order (template order unchanged).

---

## Mode-specific execution checks

- **baseline**: includes complete current-state trigger table and explicit no-action section if quiet.
- **trend**: includes at least one baseline comparison window and directional deltas.
- **incident**: prioritizes active triggers only; suppresses non-urgent narrative.
- **change-review**: anchors analysis to `--since` and separates likely-change impact from pre-existing drift.
- **portfolio**: includes per-service hot spots and shared dependency cluster risks.

---

## Required safeguards

1. **Read-only by default**. No automatic code/infra mutations from this spec.
2. **No auto-commit / no auto-PR default**. Reports are decision inputs.
3. **Human approval gate** before invoking mutating workflows (`resolve`, hunts, or manual edits).
4. **Redaction first**. Strip secrets/tokens/PII from logs or payload excerpts.
5. **Bounded retention** of generated artifacts to control noise and risk.
6. **Actionable output over raw dumps**. Include evidence snippets, not full-volume logs.
7. **Explicit non-recommendations**. Say when no action is justified.

Writing rules:

- No metric-free urgency language.
- No recommendation without threshold, delta, or explicit policy trigger.
- If confidence is low, recommend data collection first, not remediation.

---

## Report structure

```markdown
# System Digest — <YYYY-MM-DD> [mode: <mode>]

## Executive summary
- <5-8 bullets, highest impact first>

## Trigger table
| Trigger | Evidence | Impact | Urgency | Owner |
|---|---|---|---|---|

## Risks (ordered)
### 1. <risk>
- Evidence: <file:line / metric>
- Why now: <one sentence>
- Next action: <exact action>

## Recommended determinagent runs
- Immediate (0-24h): <invocation + why>
- Near-term (1-7d): <invocation + why>
- Later (8-30d): <invocation + why>

## Cost / capacity notes
- <low/likely/high estimate ranges if available>

## Honest non-recommendations
- <considered, rejected, why>
```

---

## Invocation

This spec is invoked via `INVOCATIONS.md` as `auto-report`.

Standard invocation:

```
Read $DETERMINAGENTS_HOME/specs/AUTOMATED_REPORTING.md and run it in
--mode=<baseline|trend|incident|change-review|portfolio>.

Optional:
  --window=<7d|30d|custom>
  --since=<timestamp-or-release-tag>
  --services=<csv>
  --max-findings=<N>

Write report to docs/reports/SYSTEM_DIGEST_<YYYY-MM-DD>.md and, if possible,
docs/reports/signals/SYSTEM_DIGEST_<YYYY-MM-DD>.json.

Do not mutate code or infrastructure. If mutating follow-up is warranted,
recommend the exact determinagent invocation(s) and stop.
```

## Conventions

- One mode per run.
- Prefer evidence from existing reports first; collect new runtime snapshots only when needed.
- Always name confidence and unknowns for causal claims.
- Keep recommendations sequenced by urgency and reversibility.
