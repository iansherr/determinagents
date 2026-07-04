---
audit: STUB_AND_COMPLETENESS
date: 2026-06-07
---

# Stub & Completeness Audit — 2026-06-07

## Severity rubric (this audit)

| Severity | Criteria |
|----------|----------|
| **P0 — Broken Feature** | User-facing feature fails silently in production |
| **P1 — Hidden Gap** | Admin/internal feature shows empty or wrong data |
| **P2 — Planned Feature** | UI exists for a future feature; stub is intentional but undocumented |
| **P3 — Dead Code** | Endpoint, handler, or UI path that nothing reaches |

## Summary
- Phantom endpoints: 0
- Stub handlers: 0
- Unregistered behaviors / prompt blocks: 7
- Dead features / duplicate documentation: 0 (The duplicate block in INVOCATIONS.md has been resolved)
- Subagent directory naming mismatches: 4
- Total findings: 11 (P0: 0, P1: 7, P2: 0, P3: 4)
- Phases run: Phase 0, Phase 1 (adapted for doc references), Phase 2 (adapted for scripts and agent configs), Phase 3 (adapted for token mappings)

---

## P0 — Broken Features
*None.*

---

## P1 — Hidden Gaps
The following behaviors are defined in the library's `audits/` folder and listed in the `INVOCATIONS.md` vocabulary table, but have **no detailed prompt blocks or sections** defined in `INVOCATIONS.md`. As a result, they are excluded from the host-tool command materializer.

| # | Behavior / Audit | File Path | Token | Impact | Suggested Fix |
|---|---|---|---|---|---|
| 1 | `ADVERSARIAL_HARDENER` | [audits/ADVERSARIAL_HARDENER.md](../../audits/ADVERSARIAL_HARDENER.md) | `adversarial` | Missing from command materialization; cannot be run as a subagent or slash command. | Add a prompt block under `## Audits (read-only)` or as a mutating section in `INVOCATIONS.md`. |
| 2 | `LOOP_BOOTSTRAP` | [audits/LOOP_BOOTSTRAP.md](../../audits/LOOP_BOOTSTRAP.md) | `init-loops` | Missing from command materialization; cannot be run as a subagent or slash command. | Add a prompt block section in `INVOCATIONS.md`. |
| 3 | `LOOP_ORCHESTRATOR` | [audits/LOOP_ORCHESTRATOR.md](../../audits/LOOP_ORCHESTRATOR.md) | `loop-orchestrator` | Missing from command materialization; cannot be run as a subagent or slash command. | Add a prompt block section in `INVOCATIONS.md`. |
| 4 | `PARSER_FUZZER` | [audits/PARSER_FUZZER.md](../../audits/PARSER_FUZZER.md) | `fuzzer` | Missing from command materialization; cannot be run as a subagent or slash command. | Add a prompt block section in `INVOCATIONS.md`. |
| 5 | `RECURSIVE_IMPROVEMENT` | [audits/RECURSIVE_IMPROVEMENT.md](../../audits/RECURSIVE_IMPROVEMENT.md) | `recursive` | Missing from command materialization; cannot be run as a subagent or slash command. | Add a prompt block section in `INVOCATIONS.md`. |
| 6 | `SCENARIO_CHAINER` | [audits/SCENARIO_CHAINER.md](../../audits/SCENARIO_CHAINER.md) | `chainer` | Missing from command materialization; cannot be run as a subagent or slash command. | Add a prompt block section in `INVOCATIONS.md`. |
| 7 | `UX_TOKEN_REFACTOR` | [audits/UX_TOKEN_REFACTOR.md](../../audits/UX_TOKEN_REFACTOR.md) | `token-refactor` | Missing from command materialization; cannot be run as a subagent or slash command. | Add a prompt block section in `INVOCATIONS.md`. |

---

## P2 — Planned Features
*None.*

---

## P3 — Dead Code / Documentation Cruft

| # | Issue | Location | Impact | Suggested Fix |
|---|---|---|---|---|
| 1 | Subagent directory naming mismatch (`handoff`) | `~/.gemini/antigravity-cli/agents/audit-design-handoff` | Materialization generated directory name differs from naming conventions derived from token `handoff`. | Standardize folder name to `audit-handoff` or update token in `INVOCATIONS.md`. |
| 2 | Subagent directory naming mismatch (`next`) | `~/.gemini/antigravity-cli/agents/pick-next` | Materialization generated directory name differs from naming conventions derived from token `next`. | Standardize folder name to `next` or update token in `INVOCATIONS.md`. |
| 3 | Subagent directory naming mismatch (`p0`) | `~/.gemini/antigravity-cli/agents/audit-p0-sweep` | Materialization generated directory name differs from naming conventions derived from token `p0`. | Standardize folder name to `audit-p0` or update token in `INVOCATIONS.md`. |
| 4 | Subagent directory naming mismatch (`testing`) | `~/.gemini/antigravity-cli/agents/testing-creator` | Materialization generated directory name differs from naming conventions derived from token `testing`. | Standardize folder name to `testing` or update token in `INVOCATIONS.md`. |

---

## Patterns observed
1. **Incomplete INVOCATIONS.md Documentation**: The library has grown multiple specialized autonomous agents (like loop-protocol related agents: `LOOP_BOOTSTRAP`, `LOOP_ORCHESTRATOR`, `RECURSIVE_IMPROVEMENT`) in the `audits/` directory, but the central `INVOCATIONS.md` prompt repository was not fully updated to contain their prompt blocks.
2. **Subagent Naming Drifts**: The prefix/suffix naming convention for subagent materialization directories under `~/.gemini/antigravity-cli/agents/` drifts from the clean vocabulary tokens used in `INVOCATIONS.md` (e.g. using suffix `-sweep` or `-creator` in directory name vs raw `p0` or `testing` in tokens).

---

## Next steps

Suggested invocations to act on this report. Copy and paste into your agent:

**Resolve all actionable findings:**

```
Run audits/RESOLVE_FROM_REPORT.md from $DETERMINAGENTS_HOME against the
report at docs/reports/STUB_AUDIT_2026-06-07.md.

Read docs/determinagents/AUDIT_CONTEXT.md first.

Triage findings into Actionable / Needs decision / Already resolved /
Invalid / Out of scope. Show me the plan before doing any work.
```

**Re-run this audit after resolution to verify clean state:**

```
/determinagents stub
```

---

## Recommendations
1. **Continuous Materialization Validation**: Implement a CI check or hook to ensure that all markdown files in `audits/` have:
   - A corresponding token in `INVOCATIONS.md`'s routing vocabulary.
   - A corresponding prompt block in `INVOCATIONS.md`.
2. **Standardize Naming Scheme**: Align generated slash command filenames/directories directly with the routing vocabulary tokens to eliminate translation mismatches.
