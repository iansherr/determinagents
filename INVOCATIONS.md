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

### Cross-audit P0 sweep

When you only have time to find showstoppers across the whole library:

```
Run all read-only audits from $DETERMINAGENTS_HOME/audits/ against this
repo with --p0-only. Surface a consolidated P0 list (audit, file:line,
one-sentence impact). No reports.
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

### Refresh AUDIT_CONTEXT

```
Review docs/determinagents/AUDIT_CONTEXT.md. For each entry: still true?
Older than 12 months on a non-conventions entry? Still earns its place?
Propose deletions and updates as a diff. Do not commit until I approve.
```

---

## Authoring new invocations

Add an entry to this file when the library grows a new behavior. Format:

```markdown
## <BEHAVIOR>
**Prerequisites**: ...

[paste-ready prompt with --flags]
```

If the same flag pattern shows up across multiple invocations, document it once in the audits-table prompt and reference it elsewhere. Resist enumerating variants of the same behavior — variants are flag combinations, not separate invocations.
