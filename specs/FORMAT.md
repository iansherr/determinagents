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

Every audit ends with a report skeleton like:

```markdown
# [Audit Name] Report — [DATE]

## Summary
- Findings: X (P0: X, P1: X, P2: X, P3: X)
- Phases run: 1, 2, 4
- Time spent: ~Xh

## P0 — [Category]
| Issue | Location | Impact | Suggested fix |
|-------|----------|--------|---------------|
| ... | path:line | ... | ... |

## P1 — ...

## Patterns observed
1–3 paragraph synthesis of root causes, not just a list.

## Recommendations
Ordered list of concrete next actions.
```

## Authoring checklist

Before committing a new audit doc:

- [ ] Discovery phase exists and is universal (or the doc is explicitly project-specific).
- [ ] Every phase is independently runnable.
- [ ] Every phase has at least one concrete command.
- [ ] Severity rubric has written criteria.
- [ ] Report template uses tables for findings.
- [ ] No prose where a command would do.
- [ ] No advice where a check would do.
