# Loop Orchestrator

## Purpose

Find and orchestrate improvement loops across a project. Scans for harnesses and targets, then schedules `RECURSIVE_IMPROVEMENT` or `ADVERSARIAL_HARDENER` loops.

## Mode: Orchestrator

This agent does not mutate application code directly. It orchestrates sub-agents that do. It writes an orchestration plan and then delegates execution.

## When to run

- When you want the agent to broadly improve performance, correctness, or security without manually specifying each target.
- As a scheduled task (e.g., weekly) to find new optimizations or harden newly added code.
- When `PICK_NEXT` recommends it due to a high density of mature harnesses.

**Model tier**: `reasoning` — requires analyzing complex codebases to identify optimization targets and orchestrating multi-step workflows.

## Output

1. **Loop Plan**: `docs/reports/LOOP_PLAN_<YYYY-MM-DD>.md` containing the discovered harnesses and the scheduled improvement loops.
2. **Execution**: The agent outputs the specific `/determinagents` commands for the user to execute, or executes them sequentially if the host tool supports agent-to-agent delegation.

---

## Phase 0: Discovery (Finding the Loops)

### 0.1 Read the loop registry first

The registry is the source of truth. If `LOOP_BOOTSTRAP` has run, the project's loops are already memorialized — trust them and skip the broad scan (0.2).

```bash
cat docs/determinagents/LOOPS.md 2>/dev/null
```

If the registry exists, verify each listed harness command still runs before scheduling it (commands drift; the registry may be stale). Report any dead entries so the user can prune them. Fall through to 0.2 only if the registry is missing, or the user explicitly asked to discover *new* loops beyond it.

### 0.2 Scan for Harnesses and Benchmarks (fallback)

Find deterministic executables that measure correctness, performance, or security, taking care to **exclude dependency directories** like `node_modules` or `vendor` which are full of irrelevant upstream benchmarks.

```bash
# Safely look for standard benchmark directories and scripts, avoiding noise
find . -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/\.git/*" -type f \( -name "*bench*.sh" -o -name "*bench*.js" -o -name "*bench*.ts" -o -name "*perf*.py" \)

# Other loop-config patterns that indicate existing autonomous improvement loops
grep -i 'loop' docs/determinagents/AUDIT_CONTEXT.md 2>/dev/null
find . -not -path "*/node_modules/*" -not -path "*/\.git/*" -type f \( -name "PLAN.md" -o -name "AGENTS.md" -o -name "loop.sh" -o -name "CLAUDE.md" \)
```

Inspect `package.json`, `Makefile`, or `Cargo.toml` for scripts like `bench`, `perf`, `fuzz`. Verify these scripts actually exist and run without errors locally before scheduling them. If this scan finds loops worth keeping, recommend `/determinagents init-loops` afterwards so they get memorialized in the registry instead of being re-discovered every run.

### 0.3 Identify Regression Targets

Review recent `STUB_AND_COMPLETENESS` or `ERROR_HANDLING` reports. A broken flow with a regression test is a candidate for `RECURSIVE_IMPROVEMENT` (goal: fix the bug without breaking the test).

---

## Phase 1: Planning and Triage

For every harness discovered, formulate a concrete loop configuration.

| Target | Harness Command | Loop Type | Goal |
|---|---|---|---|
| `src/parser.ts` | `npm run bench:parser` | `RECURSIVE_IMPROVEMENT` | Improve parsing speed by 20% |
| `src/api.js` | `npm run test:api` | `ADVERSARIAL_HARDENER` | Discover unhandled edge cases in input validation |

**Triage Rules (Careful Execution Constraints)**:
1. **Safety First**: Verify that the harness is safe to run autonomously. It must not execute destructive actions against production databases or live external services.
2. **Determinism**: Exclude flaky tests. A harness MUST be 100% deterministic to be used in a self-improvement loop.
3. **Structured Context**: Ensure a clearly defined `PLAN.md` or PRD exists for the loop to govern its behavior and prevent it from spiraling off-topic (e.g., following the Ralph Wiggum or OCLoop patterns).
4. **Prioritization**: Target bottlenecks with high execution time or frequent regressions.
5. **Agent Exhaustion**: Limit the plan to the top 3 most valuable loops.

---

## Phase 2: Orchestration (Execution)

For each target in the plan, the orchestrator issues the exact invocation to run the loop.

Example:
```bash
/determinagents recursive --goal="Improve parsing speed by 20%" --harness="npm run bench:parser" --max-iterations=3
```

If the host environment allows the agent to run sub-agents, execute these loops sequentially, gathering the `EOI` (Evidence of Improvement) from each.

---

## Phase 3: Synthesis

After all scheduled loops complete (or after generating the plan for the user), write the final synthesis to `docs/reports/LOOP_PLAN_<YYYY-MM-DD>.md`.
- Which loops succeeded?
- Which hit a "Hard Ceiling"?
- Total aggregated improvement (e.g., "Saved 400ms across 3 critical paths").

---

## Next steps
1. Run the suggested `/determinagents recursive ...` commands generated in the plan.
2. (Optional) Run `/determinagents refresh-context` to add these successful optimizations to the project's permanent context.
