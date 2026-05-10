# Invocations

Paste-ready prompts for every behavior in this library. Each invocation is self-contained — copy it, fill in the `<ANGLE_BRACKET>` placeholders, hand it to a coding agent.

This file is the single source of truth for invocations. Individual audit/spec docs may show one example each for context, but treat this file as authoritative.

---

## Shared conventions (all invocations inherit these)

Every invocation in this file assumes the following — agents reading them should treat these as defaults unless the prompt overrides them:

1. **Library location**: this library is at `${DETERMINAGENTS_HOME:-$HOME/.determinagents}/` (adjust if installed elsewhere).
2. **Project context first**: if `docs/determinagents/AUDIT_CONTEXT.md` exists in the target repo, read it before running any audit. Apply its calibrations (severity adjustments, known false-positives, ignore paths).
3. **Reports go to** `docs/reports/<NAME>_<YYYY-MM-DD>.md` in the target repo.
4. **Findings classified P0–P3** per the rubric in the audit doc.
5. **Read-only by default.** Three docs mutate the codebase, all gated behind explicit per-action approval and a disposable-workspace requirement: `audits/RESOLVE_FROM_REPORT.md` (works through audit-report findings), `audits/SECURITY_HUNT.md` (agentic vulnerability hunting with execution), and `audits/TESTING_CREATOR.md` (writes new tests across four tiers).
6. **Each finding includes file:line and a concrete fix** — never "fix this."
7. **Discovery first.** Phase 0 of every audit identifies project shape; later phases reference what discovery found.

You can prepend this short preface to any invocation if the agent isn't already aware of these conventions:

```
Library at ${DETERMINAGENTS_HOME:-$HOME/.determinagents}/. Read
docs/determinagents/AUDIT_CONTEXT.md if present and apply its
calibrations. Commit reports to docs/reports/ with a date-stamped name.
```

---

## 1. Audits (read-only)

Each audit has three scope variants. Default is `standard`.

### 1.1 STUB_AND_COMPLETENESS

**When**: anytime; especially after sprints that shipped features without integration tests, or when an internal panel "looks empty."

**Variants**: `quick` (Phase 1 only), `standard` (Phases 1–3), `deep` (all phases).

```
Run audits/STUB_AND_COMPLETENESS.md from the determinagents library at
$DETERMINAGENTS_HOME against this repo, scope=<quick|standard|deep>.

Read docs/determinagents/AUDIT_CONTEXT.md first if it exists.

Produce the report per the doc's template at
docs/reports/STUB_AUDIT_<YYYY-MM-DD>.md. Include file:line for every finding
and a concrete suggested fix. Do not commit until I review.
```

### 1.2 SECURITY_PENTEST

**When**: quarterly; before a release that changes auth or external surface; after any security incident.

**Variants**: `quick` (Phases 1–2 — auth + secrets), `standard` (Phases 1–4), `deep` (all phases, with written exploit sketch for each P0/P1).

```
Run audits/SECURITY_PENTEST.md from $DETERMINAGENTS_HOME against this repo,
scope=<quick|standard|deep>.

Read docs/determinagents/AUDIT_CONTEXT.md first.

Report to docs/reports/SECURITY_AUDIT_<YYYY-MM-DD>.md. For every P0/P1
finding, include a written exploit sketch (1–3 sentences) describing how
an attacker would actually use the vulnerability.

If this repo is publicly visible, surface P0 findings to me directly before
writing them to the public report.
```

### 1.3 DATA_FLOW_TRACE

**When**: after a feature ships; after a "works in dev, broken in prod" report; before extracting a service.

**Variants**: per-flow only (no quick/standard/deep — the audit is already scoped to one flow).

```
Run audits/DATA_FLOW_TRACE.md from $DETERMINAGENTS_HOME against this repo for the
flow: <FLOW_NAME — e.g., "save bookmark", "submit job application",
"update profile">.

Read docs/determinagents/AUDIT_CONTEXT.md first.

Trace the flow end-to-end through all phases (UI → network → handler → DB →
read path → cache). Build the field round-trip table. Report to
docs/reports/DATA_FLOW_<flow-slug>_<YYYY-MM-DD>.md.
```

### 1.4 ERROR_HANDLING

**When**: anytime; especially after "I clicked X and nothing happened" support tickets.

**Variants**: `quick` (Phases 1–2 — frontend + backend swallowing), `standard` (Phases 1–4), `deep` (all phases).

```
Run audits/ERROR_HANDLING.md from $DETERMINAGENTS_HOME against this repo,
scope=<quick|standard|deep>.

Read docs/determinagents/AUDIT_CONTEXT.md first — pay attention to
the "Approved silent fallbacks" section so you don't re-flag intentional
ones.

Report to docs/reports/ERROR_HANDLING_<YYYY-MM-DD>.md. For every finding,
answer: "what does the user see when this fails?"
```

### 1.5 TEST_GAPS

**When**: before a release on a critical path; after an incident, to find sibling bugs; quarterly.

**Variants**: `quick` (Phases 0–2 — inventory + failure-mode coverage), `standard` (Phases 0–4), `deep` (all phases including mutation test).

```
Run audits/TEST_GAPS.md from $DETERMINAGENTS_HOME against this repo,
scope=<quick|standard|deep>.

Read docs/determinagents/AUDIT_CONTEXT.md first — its
"Critical paths (project's own list)" is the input for Phase 1.

Report to docs/reports/TEST_GAPS_<YYYY-MM-DD>.md. Include the critical-path
coverage matrix and, for deep scope, the mutation-test results.
```

### 1.6 DOCS_DRIFT

**When**: quarterly; before publishing externally; after a major refactor or service merge/split.

**Variants**: `quick` (Phases 0–2 — README + architecture), `standard` (Phases 0–5), `deep` (all phases including code-block bitrot test).

```
Run audits/DOCS_DRIFT.md from $DETERMINAGENTS_HOME against this repo,
scope=<quick|standard|deep>.

Walk the README setup section as if you'd never seen the project. For
"deep" scope, try executing the bash blocks in docs to verify they still
work.

Report to docs/reports/DOCS_DRIFT_<YYYY-MM-DD>.md.
```

### 1.7 UX_DESIGN_AUDIT

**When**: before a release that ships visual changes; after a token update; quarterly.

**Variants**: `quick` (Phases 1–3 — token compliance + colors), `standard` (Phases 1–6), `deep` (all phases including accessibility and dark mode; requires a running app or screenshots).

```
Run audits/UX_DESIGN_AUDIT.md from $DETERMINAGENTS_HOME against this repo,
scope=<quick|standard|deep>.

Prerequisite: DESIGN.md must exist at the project root. If it doesn't,
stop and surface that — do not invent tokens.

For "deep" scope, use a running dev server at <DEV_URL> and
viewports 390/768/1280 (or per DESIGN.md breakpoints). Save screenshots
to docs/reports/screenshots/ux-audit-<YYYY-MM-DD>/.

Report to docs/reports/UX_DESIGN_AUDIT_<YYYY-MM-DD>.md. For every drift
finding, include both the computed value and the expected DESIGN.md token.
```

### 1.8 P0-only triage (any audit, fast)

When you only have time to find showstoppers:

```
Run audits/<AUDIT_NAME>.md from $DETERMINAGENTS_HOME against this repo, but stop
after identifying P0 findings. Skip P1/P2/P3 entirely. Surface P0s to me in
chat — do not write a full report. If there are no P0s, say so.
```

---

## 2. RESOLVE_FROM_REPORT (mutating)

Takes a report from any read-only audit and works through findings — one at a time, with explicit approval per fix, separate commits per fix, and verification. The standard workflow after running an audit and reviewing the report.

**Prerequisites**: a report at `docs/reports/<NAME>_<YYYY-MM-DD>.md` from any read-only audit, plus a clean working tree.

### 2.1 Resolve all actionable findings (default)

If you don't pass a report path, the agent auto-discovers the most recent report in `docs/reports/` and confirms before proceeding.

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME.

[Optional: target report at docs/reports/<REPORT_FILENAME>. If omitted,
auto-discover the most recent.]

Read docs/determinagents/AUDIT_CONTEXT.md first.

Triage findings into Actionable / Needs decision / Already resolved /
Invalid / Out of scope. Show me the plan before doing any work. Then
work through Actionable findings in severity order (P0 first), using
the shorthand approval format (y/n/d/e/s/i/q per finding). One commit
per fix. Stop on first failure or `q`.

Append a ## Resolution section to the report when finished.
```

### 2.2 Resolve only P0 findings (fast path)

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME against the
report at docs/reports/<REPORT_FILENAME>, scope=P0.

Same triage and approval flow as the default invocation, but stop after
P0 is clean. Surface remaining P1/P2/P3 in the resolution annotation
without resolving them.
```

### 2.3 Resolve a single finding

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME against the
report at docs/reports/<REPORT_FILENAME>. Scope to finding <SEVERITY> #<NUMBER>
only.

Skip triage of other findings. Verify the issue still exists, plan the
fix, get approval, implement, verify, commit, annotate. Done.
```

### 2.4 Resolve a category

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME against the
report at docs/reports/<REPORT_FILENAME>. Scope to findings tagged
<CATEGORY — e.g., "phantom endpoints", "stub handlers", "orphan compiled JS">.

Apply the standard per-finding loop within that category only.
```

---

## 3. TESTING_CREATOR (mutating)

Implements tests across four tiers (Adversarial, Chaos, Simulation, Forensics) beyond what `TEST_GAPS.md` covers. Each tier is an independent session.

**Prerequisites for all tiers**: `audits/TEST_GAPS.md` and `audits/SECURITY_PENTEST.md` reports must exist in `docs/reports/`. Stop and run those first if they don't.

### 3.1 Tier 1 — Adversarial

```
Run Phase 1 of audits/TESTING_CREATOR.md from $DETERMINAGENTS_HOME against
service <SERVICE_NAME>.

Read the most recent docs/reports/SECURITY_AUDIT_*.md for input.

Survey existing RBAC tests, JWT/token negative tests, and fuzz harnesses.
Identify gaps. Present a plan listing every (role, action, resource) triple
needing matrix coverage and every JWT parse site needing negative tests.
Get my approval before writing any test files.

After approval, implement, run, confirm tests fail when the control is
disabled and pass when enabled, then commit.

Report to docs/reports/TEST_VERIFICATION_<service>_<YYYY-MM-DD>.md.
```

### 3.2 Tier 2 — Chaos

```
Run Phase 2 of audits/TESTING_CREATOR.md from $DETERMINAGENTS_HOME against
service <SERVICE_NAME>.

Read the most recent docs/reports/DATA_FLOW_*.md if present.

Identify every external dependency (DB, object store, external API, message
queue, cache). For each, propose a chaos test (compose down, network drop,
mock 503) plus the survival mode the service should enter. Present the plan;
get my approval before writing tests or modifying service code.

After approval, implement and verify each test. Commit each tier-2 artifact
as a separate commit.
```

### 3.3 Tier 3 — Simulation

```
Run Phase 3 of audits/TESTING_CREATOR.md from $DETERMINAGENTS_HOME against
service <SERVICE_NAME>.

This requires creating a simulation/<feature>/ harness. Confirm with me
which container orchestration to use (docker-compose vs. k8s vs. existing
project convention) before scaffolding anything.

Implement the four required scenarios (big-bang start, concurrent same-user
action, rolling restart under load, partition if applicable). Each scenario
is a separate test that brings up a clean cluster and tears it down.

If the service runs only one instance and is not designed to scale, stop
and surface that — Tier 3 may not apply here.
```

### 3.4 Tier 4 — Forensics

```
Run Phase 4 of audits/TESTING_CREATOR.md from $DETERMINAGENTS_HOME against
service <SERVICE_NAME>.

Required for services holding audit logs, immutable history, signed records,
or compliance-relevant state. If this service has none of those, stop and
surface that.

Identify integrity verification sites (hash, signature, hmac). For each,
implement a fracture test that mutates persistence state and asserts the
verifier fails. Plant a honeytoken and verify the alert path fires. If
audit logs exist, test their immutability via the application's own API.
```

---

## 4. Per-project artifact bootstraps

### 4.1 DESIGN.md cold bootstrap

**When**: before running `audits/UX_DESIGN_AUDIT.md` if no DESIGN.md exists.

```
Analyze the design system of this codebase and produce a DESIGN.md at the
project root following the google-labs-code/design.md spec
(https://github.com/google-labs-code/design.md).

Begin with YAML frontmatter for all design tokens (colors, typography,
spacing, elevation, motion, radii, shadows, breakpoints). Follow with
free-form Markdown describing look-and-feel intent and design rationale.

The file must be entirely self-contained — no references to codebase paths
or CSS variables. If a token value can't be inferred from the code, mark
it `# TBD — needs design input` rather than guessing.

If a running app or screenshots are available, compare your DESIGN.md
against the rendered UI. Revise until both YAML and prose faithfully
capture the product's visual identity.
```

### 4.2 FEATURE_REGISTRY cold bootstrap

**When**: adopting the registry in a new project once it has ~10+ user-visible features.

```
Generate docs/determinagents/FEATURE_REGISTRY.md for this repo
following the spec at $DETERMINAGENTS_HOME/specs/FEATURE_REGISTRY.md.

Discovery:
1. Identify every user-visible route (frontend pages, mobile screens, API
   endpoints with user-facing behavior). Use Phase 1 commands from
   audits/STUB_AND_COMPLETENESS.md.
2. Draft an entry per the spec's required fields. Functional steps must
   be specific (DOM selectors, network calls, expected statuses) — not
   "verify it works."
3. Group by tag. Default tags: [public], [authenticated], [admin],
   [mobile], [api]. Add domain tags as features cluster.
4. Write the test infrastructure header. If the test account convention
   isn't obvious, leave a placeholder and ask me before committing.
5. Reference DESIGN.md from the design standards section if it exists.

Do not invent functional steps you cannot verify from the code. If a
feature's behavior is unclear, mark Pass criteria as
"TBD — needs product input."

Show the registry in chunks of 5 features for review before committing.
```

### 4.3 FEATURE_REGISTRY per-feature add (in-PR)

**When**: shipping a new feature; add the registry entry in the same PR.

```
I'm shipping <FEATURE_NAME> in this PR. Add an entry to
docs/determinagents/FEATURE_REGISTRY.md following the spec at
$DETERMINAGENTS_HOME/specs/FEATURE_REGISTRY.md.

The feature: <ROUTES>, <AUTH_REQUIREMENTS>, <INTENDED_BEHAVIOR>.

Use the next available ID. Match the tag conventions already in the file.
Show the entry before committing.
```

### 4.4 FEATURE_REGISTRY sync audit

**When**: quarterly; before relying on the registry as a release gate.

```
Audit docs/determinagents/FEATURE_REGISTRY.md against the codebase
following the spec at $DETERMINAGENTS_HOME/specs/FEATURE_REGISTRY.md "Sync audit"
section.

Report two lists:
1. Routes in registry but not in code (entries to remove or update)
2. Routes in code but not in registry (coverage gaps)

Plus mobile parity drift if applicable.

Report to docs/reports/REGISTRY_DRIFT_<YYYY-MM-DD>.md. Do not modify the
registry — the report is the proposal; I'll approve before changes.
```

### 4.5 AUDIT_CONTEXT cold bootstrap

**When**: first time adopting this library in a new project, after running 1–2 audits to have something to calibrate.

```
Bootstrap docs/determinagents/AUDIT_CONTEXT.md for this repo
following the workflow at $DETERMINAGENTS_HOME/specs/BOOTSTRAP.md (cold mode).

Survey the codebase: identify the auth model, deployment surface, primary
languages/frameworks, archived or dead directories, and any obvious
project conventions (JSONB hydration, code generation, monorepo layout).

Then ask me up to 5 questions about institutional knowledge that wouldn't
be visible from the code alone — recent incidents, known weak spots, areas
where severity should be calibrated differently from the universal P0–P3
rubric.

Use the template at $DETERMINAGENTS_HOME/specs/AUDIT_CONTEXT_TEMPLATE.md. Leave
sections empty rather than inventing content.

Show me the file before committing.
```

### 4.6 AUDIT_CONTEXT warm overlay (post-audit)

**When**: after completing any audit; to capture institutional knowledge surfaced during the run.

```
You just produced docs/reports/<REPORT_FILENAME>. Propose updates to
docs/determinagents/AUDIT_CONTEXT.md based on what you learned,
following $DETERMINAGENTS_HOME/specs/BOOTSTRAP.md (warm mode).

Only propose entries that:
- Are project-specific institutional knowledge (not findable by discovery)
- Would change how a future audit runs

Do not include findings themselves — those live in the report. Show a diff
of proposed changes; do not commit until I approve each entry.
```

---

## 5. Vulnerability hunting (mutating, agentic)

`SECURITY_HUNT.md` is the agentic counterpart to `SECURITY_PENTEST.md`. It modifies code, builds, and executes — give it a disposable workspace, never your primary checkout.

**Prerequisites for all variants**: project builds locally; sanitizers configured; AUDIT_CONTEXT.md `SECURITY_HUNT` section configured (build/test commands, trust boundaries, known-blocked patterns); user is in a disposable workspace (worktree, branch, or container).

### 5.1 Hunt a single file

```
Run audits/SECURITY_HUNT.md from $DETERMINAGENTS_HOME against the file
<TARGET_FILE_PATH>.

Read docs/determinagents/AUDIT_CONTEXT.md first — pay attention to the
SECURITY_HUNT section: build commands, sanitizer flags, trust boundaries,
and known-blocked attack patterns.

Confirm I'm in a disposable workspace before starting. Then verify the
build succeeds. Generate hypotheses, verify each by writing and running
testcases under sanitizers. Only confirmed bugs reach the report. Log
attempts thwarted by existing defenses under "Attempted but blocked."

Severity by observable defect class (UAF/OOB/type-confusion = P0),
NOT by ability to build an end-to-end exploit.

Report to docs/reports/SECURITY_HUNT_<target-slug>_<YYYY-MM-DD>.md and
copy testcases to docs/reports/hunt-artifacts/<report-name>/.
```

### 5.2 Hunt a single function

```
Run audits/SECURITY_HUNT.md from $DETERMINAGENTS_HOME against the function
<FUNCTION_NAME> in <TARGET_FILE_PATH>.

Same workflow as 5.1, but scope hypotheses to the function and its
immediate call graph. Skip whole-file analysis.
```

### 5.3 Hunt high-risk surface from a SECURITY_PENTEST report

```
Run audits/SECURITY_HUNT.md from $DETERMINAGENTS_HOME, taking targets
from the most recent SECURITY_PENTEST report at docs/reports/SECURITY_AUDIT_*.md.

Pick the top 3 highest-risk targets the static audit identified
(P0-flagged files, files at trust boundaries, files with elevated
calibration in AUDIT_CONTEXT). Run a SECURITY_HUNT session per target,
producing one report per target.

Surface a triage summary at the end: confirmed P0 count per target.
```

### 5.4 Confirmed-only triage (fast surface)

When you only want bugs you can immediately demonstrate:

```
Run audits/SECURITY_HUNT.md from $DETERMINAGENTS_HOME against
<TARGET_FILE_PATH>. Stop after producing 3 confirmed P0/P1 findings, or
after 30 minutes — whichever first.

Each confirmed finding must include a runnable testcase in the artifacts
directory. Report only confirmed findings; do not surface speculation.
```

---

## 6. Maintenance invocations

### 6.1 Refresh AUDIT_CONTEXT

**When**: quarterly; after a significant refactor.

```
Review docs/determinagents/AUDIT_CONTEXT.md. For each entry:
1. Is it still true? (Verify by reading current code where the entry
   references files or patterns.)
2. Is the date older than 12 months on a non-conventions entry?
3. Does it still earn its place — would removing it cause a future audit
   to produce a wrong-shaped report?

Propose deletions and updates as a diff. Do not commit until I approve.
```

### 6.2 Sweep all audits at P0-only

**When**: pre-release sanity check; ~30 minutes total.

```
Run all seven read-only audits from $DETERMINAGENTS_HOME/audits/ against this
repo, but stop each audit after identifying P0 findings only. Skip
P1/P2/P3.

Surface a single consolidated P0 list to me in chat with the audit name,
file:line, and one-sentence impact for each finding. No reports.
```

---

## Authoring new invocations

When this library grows a new behavior, add an entry here. Format:

```markdown
### N.N <BEHAVIOR_NAME>
**When**: <one sentence>
**Variants** (if any): ...
**Prerequisites** (if any): ...

[paste-ready prompt with <ANGLE_BRACKET> placeholders]
```

If you find yourself writing the same boilerplate twice across invocations, extract it to the **Shared conventions** section at the top.
