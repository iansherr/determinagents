# Resolve from Report

## Purpose

Take an audit report produced by any read-only audit in this library and work through its findings — one at a time, with explicit per-finding approval, separate commits per fix, and verification that each issue is actually resolved before moving on.

This doc is **mutating** — it writes code, runs tests, and creates commits. The only other mutating doc in the library is `TESTING_CREATOR.md`. Both follow the same discipline: stop and confirm before each action; commit each change separately; never bundle.

## Prerequisites

- An audit report at `docs/reports/<NAME>_<YYYY-MM-DD>.md` produced by one of the read-only audits. The report must follow the format specified in `specs/FORMAT.md` (severity rubric, file:line per finding, suggested fix per finding).
- A clean working tree on a branch you can commit to. The resolver does not stash or shelve uncommitted work — it stops if `git status` is dirty.
- Tests that run locally (or a documented "tests don't run, skip verification" decision in `AUDIT_CONTEXT.md`).

## When to run

After reviewing an audit report and deciding to act on it. Not all findings need fixing in one session — scope is up to you (one severity tier, one category, one finding by ID, etc.).

This is **not** the right tool for refactors that span many findings as one architectural change. If a single change naturally addresses 5 findings together, do that change manually and check off the findings in the report. The resolver is for the common case where each finding is a discrete fix.

## Time estimate

Open-ended — depends on how many findings, how complex each fix is, and whether tests run. Plan in batches:

- **One severity tier**: a session
- **One category** (e.g., all "phantom endpoints" from a STUB report): a session
- **One specific finding**: minutes

## Output

- One commit per resolved finding (or per logically-grouped finding cluster).
- A `## Resolution` section appended to the report documenting which findings were addressed, which were skipped, and which were marked invalid (false positives discovered during fix work).
- An updated `AUDIT_CONTEXT.md` if patterns emerged (proposed via the warm-overlay flow in `specs/BOOTSTRAP.md`).

---

## Phase 0: Discovery & report parsing

### 0.1 Working-tree check

```bash
git status --porcelain
```

If empty: proceed. If non-empty: **stop and present the three options below.** The resolver requires a clean tree so each fix lands as its own commit, separable from in-progress work.

Do **not** auto-execute any of these — git operations on uncommitted work can lose data. Show the commands; let the user run them and re-invoke the resolver.

#### Option A — worktree (recommended in most cases)

Preserves the user's current state completely intact. Resolve session runs in an isolated checkout. Best when: WIP is unrelated to the audit findings, or when working on `main` directly.

```bash
# From the repo root:
git worktree add ../<repo-name>-resolve origin/main
cd ../<repo-name>-resolve

# After the session, merge or cherry-pick back, then:
git worktree remove ../<repo-name>-resolve
```

#### Option B — commit WIP first

Cleanest history if the WIP is already a coherent change. Best when: WIP is on a feature branch and represents one logical chunk.

```bash
git add -A
git commit -m "WIP: <describe your in-progress work>"

# Then re-invoke RESOLVE_FROM_REPORT. After the session:
# - if WIP was a draft, amend or squash as you normally would
# - if WIP and resolve fixes are independent, leave them as separate commits
```

#### Option C — stash (fragile; use sparingly)

Quick but `git stash pop` afterwards may conflict with resolve commits. Best when: WIP is trivial and unlikely to overlap with audit-fix paths.

```bash
git stash push -u -m "WIP before resolve session"

# Re-invoke RESOLVE_FROM_REPORT. After:
git stash pop
# If pop conflicts: resolve manually. Don't try to clever-merge resolver
# commits with stashed changes — stash is meant for short-lived WIP.
```

#### Recommending the right option

The resolver should look at what's modified and recommend:

| Pattern in `git status` | Recommend |
|------------------------|-----------|
| Many unrelated files (mixed CSS / config / docs / code) | Worktree (Option A) |
| All on a feature branch, all related | Commit WIP (Option B) |
| 1–3 small files, clearly trivial | Stash (Option C) |
| User is on `main` with uncommitted work | Worktree (Option A) — never commit directly to main |
| WIP includes the same files findings will touch | Worktree (Option A) — overlap risk too high for stash |

After the user runs their chosen option and re-invokes the resolver, Phase 0.1 should pass and the session continues normally.

### 0.2 Locate the report

If the user gave a specific report path, use that. Otherwise auto-discover:

```bash
# Most recent report — confirm with user before proceeding
ls -t docs/reports/*.md 2>/dev/null | head -5
```

Show the top 3 candidates with their dates and ask which (or confirm the most recent). Don't silently pick — reports older than 7 days are likely stale and should be re-run, not resolved.

### 0.3 Read the report

Locate the report at `docs/reports/<REPORT_NAME>`. Parse:

- Audit type and date (used to detect staleness)
- Findings table(s), grouped by severity
- Per-finding fields: severity, location (file:line), description, suggested fix

If the report does not follow the format spec (no severity rubric, missing file:line, no suggested fix per finding), stop and surface the problem. A malformed report can't be resolved reliably.

### 0.4 Staleness check

Compare the report date to recent git activity:

```bash
git log --since='<REPORT_DATE>' --oneline | head -20
```

If many commits have landed since the report was produced, warn the user: findings may already be resolved or the codebase may have moved. Recommend re-running the audit before continuing.

### 0.5 Read AUDIT_CONTEXT

If `docs/determinagents/AUDIT_CONTEXT.md` exists, read it. Apply:

- **Severity calibrations** — use the project's calibrated severities, not the universal rubric defaults.
- **Approved silent fallbacks / known false-positives** — if a finding overlaps with a known false-positive entry, propose marking it invalid rather than fixing.
- **Sensitive paths** — fixes touching these paths get extra confirmation.

---

## Phase 1: Triage

Before doing any work, present a triage view to the user.

### 1.1 Classify each finding

For each finding in the report, classify:

| Status | Meaning |
|--------|---------|
| **Actionable** | Fix is well-scoped; resolver can implement |
| **Needs decision** | Fix requires product/architectural choice (e.g., "remove or implement?"); surface to user, do not fix |
| **Already resolved** | Verification shows the issue no longer exists in the current code |
| **Invalid** | Finding is a false positive (per AUDIT_CONTEXT or current investigation) |
| **Out of scope** | User explicitly excluded this severity tier or category from the session |

### 1.2 Verify "already resolved" findings

For each finding tentatively classified "already resolved", re-run the relevant discovery command from the source audit doc to confirm. Don't trust the classification without checking.

### 1.3 Present plan

Show the user:

```
Report: docs/reports/STUB_AUDIT_2026-05-09.md (4 days old, 12 commits since)

Findings:                         Status
  P0 #1 unregistered Stripe...    Actionable
  P0 #2 unregistered lockout...   Needs decision (remove or expose?)
  P1 #1 sentinel_admin stub       Actionable
  P1 #2 oauth stub                Needs decision (planned or abandoned?)
  P2 #1 system_handlers drift     Already resolved (file does not exist)
  P3 #1-15 orphan compiled JS     Actionable (batch)

Plan: address P0 #1 and P1 #1 (actionable). Surface P0 #2 and P1 #2
for your decision. Skip P2 #1 (already resolved) and P3 batch (out of
scope unless you say otherwise).

Proceed? [y/n/edit]
```

User can adjust scope before any code changes.

---

## Phase 2: Per-finding resolution loop

For each finding in the actionable set, in severity order (P0 → P3):

### 2.1 Verify the issue exists right now

Re-run the discovery command from the source audit. The report may be days old; the issue may have been fixed independently. If it's already fixed, mark resolved and skip.

### 2.2 Plan the fix

Don't trust the report's "suggested fix" verbatim — read the surrounding code, write a fresh fix plan. The report may have suggested something that doesn't fit the code's current shape.

Present using this shorthand format. Single-letter responses keep the loop conversational:

```
Finding P0 #1: 10 unregistered Stripe webhook handlers
  Location: services/foo/webhook_handlers.go (handlers exist)
            services/foo/server.go (no registrations)

  Proposed fix:
    1. Add to server.go (after line 142):
       group := s.router.Group("/api/webhooks/stripe")
       group.POST("/charge.refunded", s.handleChargeRefunded)
       group.POST("/checkout.session.completed", s.handleCheckoutSessionCompleted)
       ... (8 more)
    2. Verify each handler signature matches gin.HandlerFunc
    3. Confirm Stripe webhook signature middleware is applied to /api/webhooks/stripe/*

  Tests to run after: services/foo/internal/http/...
  Out-of-scope but worth noting: signature validation appears unimplemented
  — flag for follow-up.

  [y] apply  [n] reject (mark needs-decision)  [d] show me the diff first
  [e] edit the plan  [s] skip (defer)  [i] mark invalid  [q] quit session
```

**Shorthand legend** (use exactly these letters; resist verbose alternatives):

| Key | Meaning |
|-----|---------|
| `y` | apply the proposed fix as shown |
| `n` | reject this plan; mark "needs decision" with reason |
| `d` | show the actual diff before deciding |
| `e` | user wants to modify the plan; iterate |
| `s` | skip this finding; mark "deferred" with reason |
| `i` | mark this finding "invalid" (false positive); record reason |
| `q` | stop the session entirely; annotate report with what's done |

If the user types prose instead of a letter, treat it as `e` (edit the plan) and incorporate their guidance.

### 2.3 Implement

After approval, make the change. Stay scoped to the finding — don't refactor surrounding code, don't fix unrelated issues, don't "improve while you're there." If you notice an adjacent problem, surface it as a new finding to add to the report — don't silently expand scope.

### 2.4 Verify

Run relevant tests:

```bash
# Examples — adapt to project's test framework
go test ./services/foo/internal/http/...
npm test -- services/foo
pytest services/foo/
```

If tests fail:
- If failure is caused by the fix → revert the change, re-plan, re-present
- If failure is pre-existing (test was already broken) → flag and ask user whether to proceed anyway

If no tests cover the area, surface that — recommend a `TESTING_CREATOR` Tier 1 follow-up to add coverage.

### 2.5 Commit

One commit per finding (or per logically-grouped finding cluster — e.g., the 10 Stripe handlers from P0 #1 might be one commit, since they're a single coherent change).

Commit message format:

```
<type>: <short description from finding>

Resolves <REPORT_NAME>:<SEVERITY> #<NUMBER>
<1-3 sentence rationale>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

Example:

```
fix(billing): register Stripe webhook handlers

Resolves STUB_AUDIT_2026-05-09:P0 #1

10 webhook handlers existed in webhook_handlers.go but had no router
registrations, so Stripe events for refunds, checkout completion, and
subscription/payment failures were silently dropped. Routes added under
/api/webhooks/stripe/* with signature validation middleware.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

### 2.6 Annotate report

Append (or amend) the report's `## Resolution` section:

```markdown
## Resolution

### 2026-05-13 — session by Claude

| Finding | Status | Commit |
|---------|--------|--------|
| P0 #1 unregistered Stripe handlers | resolved | abc1234 |
| P0 #2 unregistered lockout         | needs decision (surfaced to owner) | — |
| P1 #1 sentinel_admin stub          | resolved | def5678 |
| P1 #2 oauth stub                   | deferred (product input pending) | — |
| P2 #1 system_handlers drift        | already resolved before session | — |
| P3 #1-15 orphan compiled JS        | out of scope this session | — |
```

The annotated report is a separate commit at the end of the session, not bundled with fix commits.

### 2.7 Loop or stop

Continue to next finding. If user says "stop" or a fix verification fails irrecoverably, halt and write the resolution annotation for what was completed.

---

## Phase 3: Close-out

### 3.1 Re-run the source audit (recommended)

After resolving findings, re-run the audit that produced the report. New report should show fewer findings (or surface new findings the resolution exposed).

This is **not done automatically** — the user opts in. Re-running an audit is a fresh session.

### 3.2 Propose AUDIT_CONTEXT updates

If patterns emerged during resolution that future audits should know about, propose `AUDIT_CONTEXT.md` updates per the warm-overlay flow in `specs/BOOTSTRAP.md`. Examples:

- A grep pattern that matched a known-safe construct → add to "Known false-positives"
- A category of finding that's actually expected → add to "Approved silent fallbacks" or equivalent
- A severity that needed adjusting in practice → update "Severity calibrations"

Diff is shown to user; nothing committed without approval.

---

## Severity rubric (for the resolver itself, not for findings)

The findings already have severities from the source audit. This rubric is about **resolver outcomes**:

| Outcome | When |
|---------|------|
| **Resolved** | Fix applied, verified, committed |
| **Already resolved** | Verification showed no issue at session start |
| **Invalid** | Finding determined false-positive during work |
| **Needs decision** | Fix requires product/architectural input; surfaced to owner |
| **Deferred** | Owner chose to defer; reason recorded |
| **Failed** | Fix attempted but couldn't verify; reverted; surface to owner |

Every finding in the actionable set must end in one of these outcomes. No silent skips.

---

## Implementation rules

- **One finding at a time.** No batching unless findings are obviously the same change.
- **Plan before implementing.** Show the plan, get approval. Resist the urge to skip planning for "obvious" fixes — half of them aren't.
- **Stay scoped.** If you notice an adjacent issue, add it to the report's findings list — don't fix it silently in the same commit.
- **Never bypass tests.** If tests fail and you can't tell why, stop and surface. Don't revert and try again with a different fix; understand the failure first.
- **Never amend or force-push.** Each fix is a forward-only commit. The report's resolution annotation is the audit trail.
- **Commit messages reference the report.** `Resolves <REPORT_NAME>:<SEVERITY> #<NUMBER>` is the durable link from code change back to audit finding.
- **If working on shared branch, surface that early.** Some teams have main-branch hygiene rules. Confirm where commits should land before committing.

---

## Anti-patterns

- **"While I'm in here..." scope creep.** Adjacent issues become new findings, not silent commits. The resolver is a precision tool, not a refactor session.
- **Fixing without verifying the issue still exists.** Reports go stale. Always re-run the discovery command first.
- **Trusting the report's suggested fix.** It's a starting point, not a recipe. Read the code, write a fresh plan.
- **Bundling fixes "to save commits."** Separate commits make review and revert tractable. The audit trail depends on this.
- **Filling in `## Resolution` without verifying.** A resolution annotation that says "resolved abc1234" must point at a commit where the finding is actually addressed.

---

## Composition with other docs

- **Source**: any report from `audits/STUB_AND_COMPLETENESS.md`, `audits/SECURITY_PENTEST.md`, `audits/DATA_FLOW_TRACE.md`, `audits/ERROR_HANDLING.md`, `audits/TEST_GAPS.md`, `audits/DOCS_DRIFT.md`, `audits/UX_DESIGN_AUDIT.md`.
- **Follow-up for security fixes**: pass to `audits/TESTING_CREATOR.md` Tier 1 (Adversarial) to add executable coverage proving the fix can't regress.
- **Follow-up for chaos-related fixes**: pass to `audits/TESTING_CREATOR.md` Tier 2 (Chaos) to verify survival mode.
- **Re-audit**: re-run the source audit after resolution to confirm clean state.

The chain: **audit → report → resolve → re-audit → testing_creator** is the full safety pattern. Each step is its own session.
