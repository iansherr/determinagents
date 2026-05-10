# Self-Directed Agent Doc Format

This is the spec every audit document in this directory follows. Use it when authoring a new audit or when adapting one of these docs into a project-specific version.

## Required sections

A self-directed agent doc MUST contain, in order:

1. **Title** — one line, action-oriented (e.g., "Stub & Completeness Audit").
2. **Purpose** — 2–4 sentences. What this audit finds and why it matters. Name the failure mode it prevents.
3. **When to run** — anytime / quarterly / before release / after incident X. Include risk level (read-only vs. mutating).
4. **Time estimate** — quick / standard / deep, with rough minutes.
5. **Output** — where the report goes and what it's named.
6. **Discovery phase** — the FIRST phase. Universal docs have no hardcoded paths; the agent learns the layout here. Project-specific adaptations replace this with known paths.
7. **Audit phases** — numbered, each scoped enough to run independently. Each phase has:
   - A goal (what this phase finds)
   - Concrete commands (grep, find, build, test invocations)
   - What to record (file:line, severity, suggested fix)
8. **Severity rubric** — explicit P0/P1/P2/P3 (or Critical/High/Medium/Low) criteria. Without this, severities drift between runs.
9. **Report template** — the markdown skeleton for the final report. Tables preferred over prose for findings.

## Rules

**Repo-specific OR self-discovering, never generic.** "Look for security issues" is useless. Either name the file (`services/auth/middleware.go:42`) or give the agent a discovery command (`grep -rn 'jwt.Parse\|verifyToken' --include='*.go' --include='*.ts'`).

**Read-only by default.** If a phase mutates state (writes files, runs migrations, hits external APIs), label it `[MUTATING]` and explain why it's necessary.

**Phaseable.** A user must be able to say "run Phase 3 only." Phases must not depend on outputs from prior phases except via the report.

**Severity-scored.** Every finding gets a severity. Severities have written criteria, not vibes.

**Concrete fixes.** A finding is incomplete without a suggested fix at the same file:line. "Add input validation" is not a fix; "Wrap line 42 in `validator.IsURL(input)` before passing to `http.Get`" is.

**No emoji, no decoration.** These docs are tools, not marketing.

## Discovery phase pattern

The discovery phase replaces what a project-specific doc would hardcode. A typical discovery phase has the agent:

1. Identify languages and frameworks (`package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, etc.).
2. Identify the entry points (router files, `main.*`, `app.*`, server bootstrap).
3. Identify the frontend/backend boundary (where API calls originate, where they're served).
4. Identify the test framework and test layout.
5. Identify the deployment surface (Dockerfiles, k8s manifests, CI workflows).

Subsequent phases reference what discovery found, e.g., "for each route file identified in Discovery 1.2..."

## Severity rubric template

Use this default unless the audit needs a domain-specific scale:

| Severity | Criteria | Action |
|----------|----------|--------|
| **P0** | User-facing failure, security vulnerability, or data loss vector | Fix immediately |
| **P1** | Broken feature behind a feature flag or admin path; high-risk pattern | Fix this sprint |
| **P2** | Code smell or fragility that has not yet caused a bug | Backlog |
| **P3** | Dead code, stylistic, or aspirational | Delete or document |

## Report template

Every audit produces a report following this structure. Reports are self-contained — a reader 3 weeks later should not have to look up the rubric or guess what to do next.

```markdown
# [Audit Name] Report — [DATE]

## Severity rubric (this audit)
- **P0**: [one-line definition from this audit's rubric]
- **P1**: [one-line definition]
- **P2**: [one-line definition]
- **P3**: [one-line definition]

## Summary
- Findings: X (P0: X, P1: X, P2: X, P3: X)
- Phases run: 1, 2, 4
- Time spent: ~Xh

## P0 — [Category]
| # | Issue | Location | Impact | Suggested fix |
|---|-------|----------|--------|---------------|
| 1 | ... | path:line | ... | ... |

## P1 — ...

## Patterns observed
1–3 paragraph synthesis of root causes, not just a list.

## Next steps

Suggested invocations to act on this report. Copy and paste into your agent.

**Resolve all actionable findings:**

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME against the
report at <THIS_REPORT_PATH>.

Read docs/determinagents/AUDIT_CONTEXT.md first.

Triage findings into Actionable / Needs decision / Already resolved /
Invalid / Out of scope. Show me the plan before doing any work.
```

**Resolve P0 only (fast path):**

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME against the
report at <THIS_REPORT_PATH>, scope=P0.
```

**Re-run this audit after resolution to verify clean state:**

```
[same invocation that produced this report]
```

## Recommendations
Ordered list of concrete next actions, separate from the per-finding fixes
above. Use this for cross-cutting recommendations (e.g., "establish a
convention for X", "consider migration to Y").
```

The `## Severity rubric (this audit)` block is filled in from the audit doc's rubric — copied verbatim so the report is self-contained.

The `## Next steps` block is filled in by the agent producing the report. The `<THIS_REPORT_PATH>` placeholder is replaced with the actual filename being written, so the user can copy-paste without editing.

The `## Patterns observed` and `## Recommendations` sections are distinct: patterns are *what's true*; recommendations are *what to do about it that's not already covered by per-finding fixes*.

## Harness conventions (for audits that execute code)

Some audits do their best work when given **execution capability** — the ability to build, modify, run, and observe the project under test, not just read its source. The pattern is *simple prompt + good harness > clever prompt + no harness*: a verification loop catches false positives that no amount of prose-prompting can.

Audits using a harness MUST follow these conventions so users have a consistent mental model and so the safety properties are predictable.

### 1. Mutating declaration

The doc's purpose section states clearly that it mutates the codebase. The README's mutating-docs table lists it.

### 2. Disposable workspace requirement (Phase 0.1)

The first phase verifies the user is in a disposable workspace — a git worktree, dedicated branch, container, or VM. Never the user's primary checkout.

If the workspace is unclear, the agent stops and asks: *"I'll be modifying source. Confirm this checkout at `<PATH>` is disposable (worktree, branch, or container)?"* No silent assumptions.

The agent never runs git operations on uncommitted user work. See `audits/RESOLVE_FROM_REPORT.md` Phase 0.1 for the canonical commit/stash/worktree-options pattern.

### 3. AUDIT_CONTEXT integration

Each harness-using audit has a section in `AUDIT_CONTEXT.md` (template in `specs/AUDIT_CONTEXT_TEMPLATE.md`) for project-specific configuration:

- Build / test / run commands
- Tool-specific flags (sanitizers, instrumentation, fault-injection libraries)
- Known-blocked patterns (don't waste cycles re-attempting defenses that already work)
- Past confirmed findings (dedup)

Without this section, the audit either stops or runs in a degraded "static-only" mode that's documented as such.

### 4. Verification loop pattern

The inner loop, common to all harness audits:

1. **Hypothesize**: agent reads code, proposes a finding (a bug, a flow break, an error path, a token drift)
2. **Test**: agent constructs a minimal experiment that would either confirm or refute the hypothesis
3. **Execute**: experiment runs in the disposable workspace
4. **Observe**: agent reads the outcome (sanitizer output, network capture, computed styles, exit code)
5. **Classify**: confirmed → finding; refuted by defense → "Attempted but blocked" entry; refuted by no-bug → discard; ambiguous → iterate
6. **Capture**: the testcase / repro / observation goes into an artifacts directory under the report

Only confirmed findings reach the report's main severity tables. Speculation does not.

### 5. Artifact capture

Every confirmed finding includes a permanent artifact (testcase, repro script, network capture, screenshot, computed-style diff) under `docs/reports/<audit>-artifacts/<report-name>/<finding-N>/`. The disposable workspace will be torn down; the artifact persists so the finding stays reproducible.

### 6. "Attempted but blocked" report section

When the agent's experiment confirms a defense thwarts a hypothesized bug, that's *positive signal about hardening* — log it under "Attempted but blocked" in the report. Validating that defenses work is part of the audit's value, not a non-finding.

### 7. Per-target scope

Harness sessions are usually scoped per-target (file, function, flow, page, component) rather than whole-codebase. Whole-codebase harness runs lose focus and produce useless reports. The user runs multiple sessions for parallelism.

### Reference implementations

- `audits/SECURITY_HUNT.md` — agentic vulnerability discovery (canonical example)
- `audits/DATA_FLOW_VERIFY.md` — observed-vs-theorized data flow tracing
- `audits/ERROR_HANDLING.md` Phase 5 — fault injection
- `audits/STUB_AND_COMPLETENESS.md` Phase 6 — endpoint verification

When authoring a new harness audit, read these for shape, not for content.

---

## Authoring checklist

Before committing a new audit doc:

- [ ] Discovery phase exists and is universal (or the doc is explicitly project-specific).
- [ ] Every phase is independently runnable.
- [ ] Every phase has at least one concrete command.
- [ ] Severity rubric has written criteria.
- [ ] Report template uses tables for findings.
- [ ] No prose where a command would do.
- [ ] No advice where a check would do.
- [ ] Report template includes `## Severity rubric (this audit)` and `## Next steps` sections.
