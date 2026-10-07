# Autonomous Completion Loop

## Purpose

Point this at any repo and have it finish the job with no further input: bootstrap
the project overlay if missing, find what's half-built (stubs, orphaned
frontend/backend wiring, broken user flows), fix what's safe to fix, and keep
cycling until there's nothing left worth flagging. This is the single
copy-paste prompt for "I have a codebase with some unfinished integrations
and I want an agent to find and finish them" — it does not require choosing
an audit first; it chooses for you, every cycle.

It composes existing library docs rather than duplicating their logic:
`specs/BOOTSTRAP.md` for the project overlay, `STUB_AND_COMPLETENESS` +
`DATA_FLOW_TRACE` as the default discovery pair, `PICK_NEXT` once a project
has enough history to rank audits itself, and `RESOLVE_FROM_REPORT` for every
fix. Every cycle is additionally bound by `specs/LOOP_PROTOCOL.md` §6
(Completion-Loop Mandates): the gate ledger, anti-circularity rule,
environment capability cache, parallel-state budget, harness-failure
triage, and credential-safety invariant. This doc is the glue, not a replacement for any of them.

## Mode: Mutating (orchestrates a Read-Only discovery phase, then the
library's existing Mutating resolve step — see Phase 2)

Requires a clean working tree before any mutating phase. Never runs on a
repo's primary checkout without a branch — see Phase 0.3.

## When to run

- Dropped into a fresh repo you want an agent to "figure out and finish."
- As the body of a host-tool recurring loop (e.g. Claude Code's `/loop`,
  a cron'd agent invocation, or a CI scheduled job) — each invocation is
  re-entrant and safe to fire repeatedly; see "Re-entrancy" below.
- When `STUB_AND_COMPLETENESS` was useful once and you want it to keep
  running itself instead of being re-invoked by hand.

**Model tier**: `default` for Phases 0, 1, 3, 4. `reasoning` for Phase 2's
triage when more than ~10 findings need prioritizing in one pass.

## Time estimate

Open-ended by design. One invocation does one bounded unit of work (one
bootstrap, one audit, or one resolve batch) and exits — see Phase 2's batch
size guidance. Plan for many invocations, not one long one, unless the host
tool supports a genuinely long-running session.

## Output

- `docs/determinagents/AUDIT_CONTEXT.md` — created or refined (Phase 0).
- `docs/determinagents/LOOPS.md` — created if missing (Phase 1).
- `docs/reports/<AUDIT>_<YYYY-MM-DD>.md` — one per discovery cycle (Phase 2).
- Commits — one per resolved finding, via `RESOLVE_FROM_REPORT`'s own
  discipline (Phase 3).
- `docs/reports/COMPLETION_LOOP_STATUS.md` — this doc's own state file,
  overwritten each cycle (not dated — it's current state, not a history).
  Human-readable: what cycle number, what was done last, what's next, what's
  blocked.

## Re-entrancy

Every invocation starts by reading `docs/reports/COMPLETION_LOOP_STATUS.md`
and the repo's actual git state — never its own memory of a prior turn. This
makes the loop safe to run as a stateless, repeated invocation (a fresh agent
session each time) rather than requiring one unbroken session. If the status
file says "Phase 3 in progress, resolving P0 #4 of 7," resume there; don't
restart Phase 2.

---

## Phase 0: Bootstrap (once per repo, then skip)

### 0.1 Check what already exists

```bash
cat docs/determinagents/AUDIT_CONTEXT.md 2>/dev/null
cat docs/determinagents/LOOPS.md 2>/dev/null
cat docs/reports/COMPLETION_LOOP_STATUS.md 2>/dev/null
ls docs/reports/*.md 2>/dev/null
```

If `AUDIT_CONTEXT.md` exists, skip to 0.3. If it's missing, continue to 0.2.

### 0.2 Cold-bootstrap AUDIT_CONTEXT.md

Follow `specs/BOOTSTRAP.md` cold mode exactly: survey auth model, deployment
surface, languages, conventions, archived/dead paths; ask up to 5 questions
about institutional knowledge discovery can't find.

**Unattended fallback.** If there is no human to answer (host tool running
this as a scheduled/looped job with no interactive turn available): do not
block. Write the overlay with each uncertain field marked
`(assumed, unattended bootstrap YYYY-MM-DD — verify)` using the most
conservative reading (e.g., assume standard severity, not calibrated down;
assume any auth gap is a real finding, not intentional). Flag these
assumptions at the top of the first `COMPLETION_LOOP_STATUS.md` so a human
reviewing later sees them immediately. Re-ask the deferred questions the next
time a human is present (detectable: the invocation is interactive).

### 0.3 Confirm disposable workspace

This doc's later phases commit code. Confirm — don't assume — the current
checkout is safe to commit to:

```bash
git status --short --branch
git branch --show-current
```

If on `main`/`master`/`trunk` with no uncommitted changes of the user's own
in progress, create a dedicated branch before Phase 3 ever runs
(`git checkout -b determinagents/completion-loop`). If the working tree is
already dirty with changes that don't look like this loop's own prior work,
stop and ask — per repo-wide convention in every library doc, never silently
stash or discard someone else's in-progress work.

Check for an `AGENTS.md`, `CONTRIBUTING.md`, or `CLAUDE.md` at the repo root
and follow its commit/branch/PR conventions for every commit this loop makes
from here on — this doc does not impose its own workflow on top of a repo
that already has one.

### 0.4 Baseline harness (recommended, not required)

If a supported testing stack is detected and no harness exists yet, recommend
`/determinagents harness --mode=baseline` before Phase 2 starts resolving
anything — a resolve loop without a safety net is just editing code and
hoping.

---

## Phase 1: Loop registry (once per repo, then skip)

If `docs/determinagents/LOOPS.md` doesn't exist, run the discovery in
`LOOP_BOOTSTRAP` (`Phase 0` of `audits/LOOP_ORCHESTRATOR.md` covers the same
scan if `LOOP_BOOTSTRAP` isn't present as its own doc in this install) to
register any existing benchmark/test loops the repo already has. This matters
so later cycles don't waste a discovery pass re-finding the same harnesses.

---

## Phase 2: Discover (every cycle)

### 2.1 Pick the audit

First cycle ever (no reports in `docs/reports/`): default to
`STUB_AND_COMPLETENESS` — it's the highest-signal starting point for "what's
half-built" on a codebase with no audit history, and needs no `--target`
flag to run broadly.

Every subsequent cycle: run `PICK_NEXT` to rank what's stale or newly
relevant against recent git history. Take its top recommendation unless it's
`SECURITY_PENTEST` and more than `--max-time` has elapsed this session — security
sweeps are worth running but shouldn't starve the completion loop's primary
job; alternate rather than let one audit type dominate every cycle.

If `PICK_NEXT`'s top pick is `DATA_FLOW_TRACE`, it needs `--target=<flow>`.
Pick the flow from the most recent `STUB_AND_COMPLETENESS` report's P0/P1
findings that mention a broken or unverified flow; if none, pick the
highest-traffic user action discovery can identify (primary auth flow,
primary create/checkout/submit action — whatever this project's core loop
is).

### 2.2 Run it

Standard phases for the chosen audit, per its own doc. Report lands at
`docs/reports/<AUDIT>_<YYYY-MM-DD>.md` as usual.

### 2.3 Update status

Write `docs/reports/COMPLETION_LOOP_STATUS.md`. It MUST include the
gate ledger per `specs/LOOP_PROTOCOL.md` §6.1 (`gate | state |
identical-outcomes | last-change`) and the environment capability
cache per §6.3 — these are the anti-circularity instruments for 2.4,
not optional commentary:

```markdown
# Completion Loop Status

**Cycle:** <N>
**Last updated:** <YYYY-MM-DD HH:MM>

## This cycle
- Ran: <AUDIT> → <report path>
- Findings: P0 <n>, P1 <n>, P2 <n>, P3 <n>

## Next
- Resolve P0+P1 from <report path> (Phase 3)

## Blocked (human decision needed)
<list, or "none">

## Assumptions made unattended (verify when a human is present)
<list, or "none">
```

---

## Phase 3: Resolve (every cycle, after 2)

Run `RESOLVE_FROM_REPORT` against the report from 2.2, `scope=P0,P1` by
default — P2/P3 accumulate across cycles and get swept in a dedicated pass
later rather than blocking the completion signal on polish.

Before any new branch, worktree, or retry, run the pre-flights in
`specs/LOOP_PROTOCOL.md` §6.4 (parallel-state budget: ≤3 open
loop-owned PRs, settle-before-spawn, scope-overlap check) and §6.5
(classify every red signal as `product` / `harness-flake` /
`environment-limit` before acting). A cycle that only restates a prior
outcome without a gate state transition violates §6.2 — pivot or
block instead.

Honor `RESOLVE_FROM_REPORT`'s own discipline exactly: per-finding approval
model, one commit per fix, stop on a genuine technical blocker (missing
credential, undecidable product question, failing prerequisite) rather than
guessing — record it under "Blocked" in the status file and move to the next
independent finding instead of stalling the whole cycle on one unresolved
item.

**Batch size.** If the host tool is a single continuous session, run the
full P0+P1 batch. If each invocation is a fresh, stateless turn (the
re-entrant case), resolving one finding per invocation is safer — large
batches in a single stateless turn risk losing track partway through with no
"was this committed?" memory. Check `git log` for the finding's own fix
before re-attempting it; `RESOLVE_FROM_REPORT`'s report `## Resolution`
section is the source of truth for what's already done.

---

## Phase 4: Verify and continue

Re-run the same audit from 2.2. Compare against the prior report: are the
resolved findings actually gone, or did the fix miss?

- Clean (no new P0/P1, prior ones resolved): update
  `COMPLETION_LOOP_STATUS.md` cycle count, go to Phase 2 for the next cycle.
- Still dirty: one more `RESOLVE_FROM_REPORT` pass against the delta before
  moving on — don't loop the same audit indefinitely; cap at 2 resolve passes
  per report, then record the remainder as "Blocked" with why, and move to
  the next cycle's audit rather than spinning.

**Stop condition.** The loop is done — not "paused," done — when a full
cycle produces zero P0/P1 across every audit `PICK_NEXT` would currently
recommend, and the "Blocked" list only contains items that genuinely need a
human decision (not technical blockers that just need more agent time).
Write that verdict plainly at the top of `COMPLETION_LOOP_STATUS.md`:
`STATUS: CLEAN — <date>`. Queue exhaustion is not a release claim; it's a
statement about this loop's own findings, nothing more.

---

## Flags

- `--max-iterations=N` — stop after N cycles regardless of status.
- `--scope=P0` — resolve only P0 each cycle (slower convergence, lowest risk
  per commit).
- `--target=<audit-name>` — skip 2.1's picker, always run this audit.
- `--unattended` — skip interactive bootstrap questions per 0.2's fallback,
  even if a human happens to be present.

## Next steps

**Start the loop (first run on a new repo):**

```
Run audits/AUTONOMOUS_COMPLETION_LOOP.md from $DETERMINAGENTS_HOME against
this repo.
```

**Resume (any later invocation, same prompt — it's re-entrant):**

```
Run audits/AUTONOMOUS_COMPLETION_LOOP.md from $DETERMINAGENTS_HOME against
this repo. Read docs/reports/COMPLETION_LOOP_STATUS.md first and resume from
there.
```

**As a host-tool recurring loop:** pass the same prompt above as the body;
no interval tuning needed beyond what the host tool already does for
re-invocation — this doc's own re-entrancy handles state.
