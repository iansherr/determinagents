# Parser Round-trip Fuzzer

## Purpose

Autonomously generate adversarial markdown strings and verify parser stability to improve a specific metric (performance, reliability, accuracy) or solve an open-ended problem. This agent implements the "recursive self-improvement" loop: generating hypotheses, modifying code, verifying the outcome against a baseline harness, and iterating until the goal is met or options are exhausted.

## Mode: Mutating

**Protocol**: This audit follows the [Recursive Self-Improvement Protocol](../specs/LOOP_PROTOCOL.md).

This agent **mutates** the codebase. It requires a disposable workspace (git worktree, branch, or container) because it will iteratively modify, test, and potentially revert code.

## When to run

- When you have a clear, measurable goal (e.g., "Make the parser 2x faster," "Reduce API errors by 10x," "Resolve this complex crash").
- When a deterministic harness already exists (or was generated via `HARNESS_CREATOR.md`) to measure success and correctness.
- When human judgment is needed for direction-setting, but the mechanical iteration (hypothesize → code → test) can be automated.

**Model tier**: `reasoning` — requires open-ended hypothesis generation, complex debugging, and experiment design.

## Flags

- `--goal="<description>"`: The specific improvement target (e.g., "Reduce memory usage in src/worker.ts by 50%").
- `--harness="<command>"`: The shell command to run the verification/benchmark (e.g., `npm run bench:worker`).
- `--max-iterations=<N>`: (Optional) Limit the number of experiment loops. Default: 5.

## Output

1. **Optimized Code**: Commits in the workspace containing the successful improvements.
2. **Improvement Report**: `docs/reports/RECURSIVE_IMPROVEMENT_<YYYY-MM-DD>.md` documenting the baseline, hypotheses tested, and final results.

---

## Phase 0: Discovery & Baseline

### 0.1 Workspace & Prerequisites
- Verify disposable workspace (must not be the primary checkout with uncommitted work).
- Verify `--goal` and `--harness` flags are provided.
- Locate the target code based on the goal.

### 0.2 Establish Baseline
- Run the provided `--harness` command before making any changes.
- Record the baseline metrics (execution time, error rate, memory usage, test pass rate).
- Ensure the harness checks for **correctness** as well as performance/metrics. (An optimization that breaks tests is a failure).

---

## Phase 1: Hypothesis Generation

Analyze the target code and the baseline results.
- Identify bottlenecks, inefficiencies, or root causes of the issue.
- Generate 1-3 distinct, testable hypotheses for achieving the goal.
- Rank the hypotheses by expected impact vs. implementation complexity.
- Select the most promising hypothesis for the current iteration.

---

## Phase 2: Experiment Implementation

Implement the code changes required by the selected hypothesis.
- Keep changes focused and atomic.
- Do not refactor unrelated code.
- If the implementation requires new dependencies, ensure they are added to the appropriate manifest (e.g., `package.json`) and installed.

---

## Phase 3: Verification & Measurement

### 3.1 Execute Harness
Run the `--harness` command against the modified code.

### 3.2 Evaluate Outcome
Compare the new results against the baseline and the goal:
- **Success (Goal Met)**: The metric meets or exceeds the target, and all correctness checks pass. Proceed to Phase 4.
- **Partial Success (Improved, Goal Not Met)**: The metric improved, and correctness checks pass. Update the baseline to this new state. Commit the changes as an incremental improvement. Return to Phase 1 for the next iteration.
- **Failure (Degradation or Broken)**: The metric worsened, or correctness tests failed.
    - Analyze the failure output to understand why the hypothesis failed.
    - Revert the changes (e.g., `git reset --hard HEAD` and `git clean -fd`).
    - Mark the hypothesis as refuted. Return to Phase 1 and select the next hypothesis.

*Loop ends when the goal is met, `--max-iterations` is reached, or all viable hypotheses are exhausted.*

---

## Phase 4: Finalization & Handover

- Ensure all successful iterations are cleanly committed.
- Generate the final report summarizing the journey from baseline to final state.
- Note any "dead ends" (refuted hypotheses) to save future agents/humans from retrying them.

---

## Severity rubric (for the loop itself)

| Severity | Criteria | Action |
|----------|----------|--------|
| **P0** | Experiment breaks the build, introduces silent failures, or fails correctness tests while claiming success. | Refute hypothesis, revert, and retry. |
| **P1** | Experiment runs but degrades the target metric significantly. | Refute hypothesis, revert, and retry. |
| **P2** | Experiment yields negligible improvement for high complexity. | Consider reverting to maintain simplicity. |
| **P3** | Code style or readability degrades significantly during optimization. | Note for human review/refactoring. |

---

## Report template

```markdown
# Recursive Improvement Report — <DATE>

## Summary
- **Goal**: <Goal Description>
- **Harness**: `<Harness Command>`
- **Iterations Run**: X / Y max
- **Outcome**: [Goal Met | Partial Improvement | Exhausted/Failed]
- **Time spent**: ~Xh

## Metrics Journey
- **Baseline**: <Metric Value>
- **Final**: <Metric Value>
- **Net Change**: <Percentage/Absolute Improvement>

## Iteration Log

### Iteration 1
- **Hypothesis**: <Description>
- **Action**: <What was changed>
- **Result**: [Success | Partial | Failed] — <Metric/Error>
- **Disposition**: [Committed | Reverted]

### Iteration 2
...

## Patterns & Discoveries
1–3 paragraph synthesis of what worked, what didn't, and why. If the loop hit a ceiling, explain the apparent constraint (e.g., "I/O bound," "framework limitation").

## Next steps

**Review the successful changes:**
```bash
git diff origin/main..HEAD
```

**Run the harness manually to verify:**
```bash
<Harness Command>
```
```

## Anti-patterns

- **Optimizing without Correctness**: Making code faster by breaking its logic. The harness MUST test correctness.
- **The "One Massive Commit"**: Trying 5 different optimizations at once. Hypotheses must be tested in isolation to know which one actually worked.
- **Ignoring the Ceiling**: Continuing to run micro-optimizations when the bottleneck has clearly shifted elsewhere (e.g., optimizing CPU loops when the task is now network I/O bound).
