# Invocations

Paste-ready prompts for every behavior in this library. One invocation per behavior; scope and target are flags, not separate variants.

This file is the canonical source. Individual audit/spec docs may show one example each as a quickstart; this file is authoritative.

---

## Shared conventions (every invocation inherits these)

1. **Library**: `${DETERMINAGENTS_HOME:-$HOME/.determinagents}/`
2. **Project context**: if `docs/determinagents/AUDIT_CONTEXT.md` exists, read it first and apply its calibrations
3. **Reports** go to `docs/reports/<NAME>_<YYYY-MM-DD>.md` in the target repo
4. **Findings** classified P0–P3 per each audit's rubric
5. **Read-only by default.** Mutating docs (RESOLVE_FROM_REPORT, SECURITY_HUNT, DATA_FLOW_VERIFY, TESTING_CREATOR) require a disposable workspace and per-action approval. Two read-only audits (STUB_AND_COMPLETENESS, ERROR_HANDLING) have an opt-in mutating Phase 6 enabled with `+harness`.
6. **Each finding** includes file:line and a concrete suggested fix
7. **Discovery first.** Phase 0 of every audit identifies project shape
8. **Execution surface boundary.** Shell `determinagents` is installer/maintenance only (`update`, `materialize`, `doctor`, etc.) and does not execute audits.
9. **Wrong-surface recovery.** If shell `determinagents` was invoked while trying to run an audit, stop that path and continue in-band with `/determinagents <behavior> [flags]`.

### Routing vocabulary (`/determinagents <behavior> [flags]`)

Use these behavior tokens for direct routing on the same command:

| Token | Expands to |
|-------|------------|
| `stub` | `STUB_AND_COMPLETENESS` |
| `security` | `SECURITY_PENTEST` |
| `data-flow` | `DATA_FLOW_TRACE` |
| `error-handling` | `ERROR_HANDLING` |
| `test-gaps` | `TEST_GAPS` |
| `docs-drift` | `DOCS_DRIFT` |
| `ux` | `UX_DESIGN_AUDIT` |
| `resource-capacity` | `RESOURCE_CAPACITY` |
| `structural-entropy` | `STRUCTURAL_ENTROPY` |
| `next` | `PICK_NEXT` (recommends which audit to run based on staleness + git history) |
| `p0` | Cross-audit P0 sweep |
| `resolve` | `RESOLVE_FROM_REPORT` |
| `structural-refactor` | `STRUCTURAL_REFACTOR` |
| `security-hunt` | `SECURITY_HUNT` |
| `flow-verify` | `DATA_FLOW_VERIFY` |
| `testing` | `TESTING_CREATOR` |
| `init` | Initialize Project bootstrap |
| `design` | `DESIGN.md` bootstrap |
| `registry` | `FEATURE_REGISTRY.md` bootstrap |
| `context` | `AUDIT_CONTEXT.md` bootstrap |
| `refresh-context` | Refresh AUDIT_CONTEXT |
| `auto-report` | `AUTOMATED_REPORTING` orchestrator |

Example direct runs:

```
/determinagents ux --target=http://localhost:3000
/determinagents security --p0-only
/determinagents resource-capacity
/determinagents p0 --p0-only
/determinagents auto-report --mode=baseline
```

Short preface that establishes these conventions for an agent that hasn't seen them:

```
Library at $DETERMINAGENTS_HOME. Read docs/determinagents/AUDIT_CONTEXT.md
if present. Reports go to docs/reports/.
```

---

## Audits (read-only)

```
Run audits/<AUDIT>.md from $DETERMINAGENTS_HOME against this repo.

Optional flags:
  --phases=N,M       Run only listed phases (default: all)
  --max-time=Xm      Soft time budget; report what was reached
  --p0-only          Stop after surfacing P0 findings; skip P1-P3
  --target=<value>   Required for DATA_FLOW_TRACE (flow name) and
                     UX_DESIGN_AUDIT (DEV_URL for live phases)
  +harness           Enable the audit's mutating Phase 6 (only
                     STUB_AND_COMPLETENESS and ERROR_HANDLING).
                     Requires harness prerequisites per specs/FORMAT.md.

Report to docs/reports/<NAME>_<YYYY-MM-DD>.md per the doc's template.
```

Substitute `<AUDIT>` with one of:

| Audit | What it finds |
|-------|---------------|
| `STUB_AND_COMPLETENESS` | Phantom endpoints, dead handlers, silent error swallowing, compiled-without-source |
| `SECURITY_PENTEST` | Auth bypass, injection, IDOR, secrets, JWT issues, exposed internals |
| `DATA_FLOW_TRACE` | Where a user action breaks between UI, network, handler, DB. Requires `--target=<flow-name>`. |
| `ERROR_HANDLING` | Silent catches, missing error UI, errors logged but not surfaced |
| `TEST_GAPS` | Scenarios the test suite would miss |
| `DOCS_DRIFT` | Claims in README/docs that the code no longer matches |
| `UX_DESIGN_AUDIT` | CSS that violates DESIGN.md tokens. For live phases (5–8) requires `--target=<dev-url>`. |
| `RESOURCE_CAPACITY` | Runtime-agnostic capacity and resource-pressure risks across k8s, docker/compose, bare metal, or unraid-style deployments. |
| `STRUCTURAL_ENTROPY` | God-files and god-modules: responsibility count, fan-in/out, change velocity. Outputs seam proposals, not refactors. |

### Cross-audit P0 sweep

When you only have time to find showstoppers across the whole library:

```
Run all read-only audits from $DETERMINAGENTS_HOME/audits/ against this
repo with --p0-only. Surface a consolidated P0 list (audit, file:line,
one-sentence impact). No reports.
```

---

## PICK_NEXT (read-only meta-audit)

Recommends which audit to run next based on report staleness, git-history surface change, and `AUDIT_CONTEXT.md` cadence preferences. Writes no report by default.

```
Run audits/PICK_NEXT.md from $DETERMINAGENTS_HOME against this repo.

Optional flags:
  --log              Write docs/reports/PICK_NEXT_<YYYY-MM-DD>.md for
                     trend-tracking (default: conversational only)
  --window=<days>    Override the analysis window (default: 90 days for
                     never-run audits; per-audit last-run otherwise)

Read docs/determinagents/AUDIT_CONTEXT.md first (CADENCE section if
present). Inventory existing reports, scan git log per audit's watch
patterns, rank, output top 3 with a paste-ready invocation for the
top pick. Honor escalations: unresolved P0s outrank new audit runs.
```

---

## RESOLVE_FROM_REPORT (mutating)

Works through findings in any audit report — one at a time, with per-finding approval (`y/n/d/e/s/i/q` shorthand), separate commits per fix, verification.

**Prerequisites**: audit report exists at `docs/reports/`; clean working tree (Phase 0.1 will offer commit/stash/worktree options if not).

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME.

Optional flags:
  --report=<path>    Specific report file (default: most recent in
                     docs/reports/, confirmed before proceeding)
  --scope=<value>    Limits which findings to address:
                       P0 | P1 | P2 | P3       — by severity
                       finding-N               — single finding
                       category:<name>         — by category tag
                       (default: all actionable in severity order)

Read docs/determinagents/AUDIT_CONTEXT.md first. Triage findings, show
plan, work through with shorthand approval. One commit per fix. Append
## Resolution to the report when done.
```

---

## STRUCTURAL_REFACTOR (mutating)

Specialization of `RESOLVE_FROM_REPORT` for `STRUCTURAL_ENTROPY` reports. Per-seam loop, contract-before-code gate, dependency-graph artifacts.

**Prerequisites**: a `STRUCTURAL_ENTROPY` report exists at `docs/reports/`; disposable workspace; tests cover the target file (run `TESTING_CREATOR` Tier 1 first if not).

```
Run audits/STRUCTURAL_REFACTOR.md from $DETERMINAGENTS_HOME.

Optional flags:
  --report=<path>    Specific structural-entropy report (default: most
                     recent STRUCTURAL_ENTROPY_*.md, confirmed)
  --scope=<value>    Limits which god-files to refactor:
                       P0 | P1 | P2 | P3      — by severity
                       file:<path>            — single file
                       (default: highest-severity single file)

Read docs/determinagents/AUDIT_CONTEXT.md first. Defer to RESOLVE Phase 0
for workspace + report discovery. Then per-file: snapshot, per-seam loop
(contract commit then move commit, lowest-coupling first), re-snapshot,
test the integrated file, optionally re-run STRUCTURAL_ENTROPY against
this file. Append ## Refactor log to the report.
```

---

## SECURITY_HUNT (mutating, agentic)

Agentic vulnerability hunting against one target. Agent gets execution capability — builds, modifies, runs the project to verify or refute bug hypotheses.

**Prerequisites**: project builds locally; sanitizers configured; disposable workspace; AUDIT_CONTEXT.md `SECURITY_HUNT` section configured.

```
Run audits/SECURITY_HUNT.md from $DETERMINAGENTS_HOME.

Required:
  --target=<file-path>            Hunt scope: a specific file
  --target=<file-path>:<func>     Or a function within a file

Optional flags:
  --confirmed-only                Stop after 3 confirmed P0/P1 or 30 min
  --from-report=<pentest-path>    Pull targets from a SECURITY_PENTEST
                                  report; run a session per top-3 target

Read docs/determinagents/AUDIT_CONTEXT.md first (SECURITY_HUNT section
has build commands, sanitizer flags, trust boundaries, known-blocked
patterns). Confirm disposable workspace. Verify the build. Generate
hypotheses, verify each with executed testcases under sanitizers. Only
confirmed bugs reach the report. Severity by observable defect class.

Report to docs/reports/SECURITY_HUNT_<target-slug>_<YYYY-MM-DD>.md;
artifacts under docs/reports/hunt-artifacts/<report-name>/.
```

---

## DATA_FLOW_VERIFY (mutating)

Drives a real user flow end-to-end and observes wire traffic + DB state. The "observed" counterpart to `DATA_FLOW_TRACE`'s "inferred."

**Prerequisites**: disposable workspace; app runs locally; AUDIT_CONTEXT.md `DATA_FLOW_VERIFY` section configured.

```
Run audits/DATA_FLOW_VERIFY.md from $DETERMINAGENTS_HOME --target=<flow-name>.

Read docs/determinagents/AUDIT_CONTEXT.md first. If a DATA_FLOW_TRACE
report exists for this flow, read it as the theorized baseline.

Drive the flow (UI or API). Capture network traffic, snapshot DB
before+after, build the observed round-trip table. Re-read after write
to check cache behavior. Test data only; tear down what you create.

Report to docs/reports/DATA_FLOW_VERIFY_<flow-slug>_<YYYY-MM-DD>.md;
artifacts under docs/reports/data-flow-artifacts/<report-name>/.
```

---

## TESTING_CREATOR (mutating)

Implements tests across four tiers beyond what `TEST_GAPS` covers. Each tier is an independent session.

**Prerequisites**: `TEST_GAPS` and `SECURITY_PENTEST` reports exist in `docs/reports/`. Stop and run those first if not.

```
Run audits/TESTING_CREATOR.md from $DETERMINAGENTS_HOME --tier=<N> --service=<name>.

  --tier=1   Adversarial   (RBAC matrix, JWT negative tests, fuzz)
  --tier=2   Chaos         (dependency-down, survival mode, timeouts)
  --tier=3   Simulation    (multi-node harness, leader election, races)
  --tier=4   Forensics     (fracture tests, honeytokens, audit immutability)

Read AUDIT_CONTEXT and the relevant prerequisite reports for input.
Survey existing coverage; present plan; get approval before writing
test infrastructure. Implement; verify each test fails when its control
is disabled and passes when enabled; commit per artifact.

Report to docs/reports/TEST_VERIFICATION_<service>_<YYYY-MM-DD>.md.
```

---

## Project Initialization (First Run)

The recommended "cold start" for a new repository. Calibrates all future audits.

```
Run PROJECT_INIT from $DETERMINAGENTS_HOME.

Phase 0: Survey codebase for existing DESIGN.md,
docs/determinagents/FEATURE_REGISTRY.md, and
docs/determinagents/AUDIT_CONTEXT.md.

Phase 1: Propose a plan to bootstrap the missing artifacts in order:
  1. DESIGN.md (Look-and-feel tokens)
  2. FEATURE_REGISTRY.md (User-visible route discovery)
  3. AUDIT_CONTEXT.md (Project calibration & institutional knowledge)

Get approval for the plan, then work through each bootstrap following
the per-artifact instructions in INVOCATIONS.md.
```

---

## Per-project artifact bootstraps

### DESIGN.md

```
Generate DESIGN.md at the project root following the
google-labs-code/design.md spec. YAML frontmatter for all design tokens
(colors, typography, spacing, elevation, motion, radii, shadows,
breakpoints), then free-form Markdown for look-and-feel intent.
Self-contained — no codebase references. Mark unknown tokens
"# TBD — needs design input" rather than guessing.

If a running app or screenshots exist, compare your DESIGN.md against
the rendered UI and revise.
```

### FEATURE_REGISTRY.md

```
Generate docs/determinagents/FEATURE_REGISTRY.md following
$DETERMINAGENTS_HOME/specs/FEATURE_REGISTRY.md.

Optional flags:
  --add=<feature-name>   Add a single entry instead of full bootstrap
                         (use during the PR that ships the feature)

Cold bootstrap: identify every user-visible route per Phase 1 of
audits/STUB_AND_COMPLETENESS.md; draft entries with required fields;
group by tag. Reference DESIGN.md if it exists. Show in chunks of 5
features for review before committing.

Drift audit: if no flag, audit existing registry against current code.
Report routes-in-registry-not-in-code and routes-in-code-not-in-registry
to docs/reports/REGISTRY_DRIFT_<YYYY-MM-DD>.md.
```

### AUDIT_CONTEXT.md

```
Bootstrap or update docs/determinagents/AUDIT_CONTEXT.md following
$DETERMINAGENTS_HOME/specs/BOOTSTRAP.md.

Optional flags:
  --from-report=<path>   Warm overlay: propose updates based on a
                         specific report's findings (default: cold
                         bootstrap with discovery + 5 questions)

Cold mode: survey codebase (auth, deployment, languages, archived dirs);
ask up to 5 questions about institutional knowledge; use the minimal
template. Leave sections empty rather than inventing content.

Warm mode: read the named report; propose entries that are project-
specific and would change how a future audit runs (no findings; that's
the report's job). Show diff; do not commit until I approve each entry.
```

---

## Maintenance

### Automated reporting (project-facing)

Use this to generate recurring, decision-ready digests from existing
DeterminAgents audit outputs and runtime snapshots.

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
JSON output must follow $DETERMINAGENTS_HOME/specs/SIGNAL_SCHEMA.md.

Do not auto-mutate code or infrastructure. Recommend exact follow-up
determinagent invocation(s) when action is required.
```

### Refresh AUDIT_CONTEXT

```
Review docs/determinagents/AUDIT_CONTEXT.md. For each entry: still true?
Older than 12 months on a non-conventions entry? Still earns its place?
Propose deletions and updates as a diff. Do not commit until I approve.
```

### Library maintenance (maintainer-only)

Three modes for keeping DeterminAgents itself current as host tools and the surrounding ecosystem evolve. Reports go to `docs/maintenance/` (gitignored).

```
Read $DETERMINAGENTS_HOME/specs/MAINTENANCE.md and run it in
--mode=<refresh|integrate|brainstorm>.

  refresh    audit current docs against host-tool reality (default)
  integrate  fold a specific external source into the library
             requires --source=<url-or-path-or-description>
  brainstorm explore where the library should grow
             optional --seed=<topic>

Reports go to docs/maintenance/<MODE>_<YYYY-MM-DD>[_<slug>].md (gitignored).
Do not modify any library files; propose edits only.

If you maintain an automated, read-only signal digest (for example
capacity/reliability/cost/drift snapshots), feed it through
`--mode=integrate --source=<digest-path>` rather than auto-editing library
content.
```

This is **not** a user audit. End users running DeterminAgents on their projects don't invoke this — it's for the library steward.

---

## Authoring new invocations

Add an entry to this file when the library grows a new behavior. Format:

```markdown
## <BEHAVIOR>
**Prerequisites**: ...

[paste-ready prompt with --flags]
```

If the same flag pattern shows up across multiple invocations, document it once in the audits-table prompt and reference it elsewhere. Resist enumerating variants of the same behavior — variants are flag combinations, not separate invocations.
