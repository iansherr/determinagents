# Spec: Recursive Self-Improvement Protocol

This protocol defines the mandates for any agent performing a `RECURSIVE_IMPROVEMENT` or `ADVERSARIAL_HARDENING` loop. It ensures that autonomous improvement doesn't lead to regression, architectural drift, or infinite cycles.

## 1. The Prime Mandate: Correctness > Performance
No improvement (speed, size, or capability) is valid if it breaks a functional test.
- **Verification**: The harness **MUST** include functional assertions, not just metrics.
- **Failure**: If an optimization passes the benchmark but fails functional tests, it must be reverted immediately.

## 2. The Rule of Three (Strategic Backtrack)
If an agent attempts to fix a failing implementation or hit a performance goal more than **3 times** without success:
1.  **Stop**: Do not attempt a 4th micro-optimization.
2.  **Re-evaluate**: List all current assumptions.
3.  **Pivot**: Propose a different architectural approach (e.g., "Switching from O(n^2) loop to a Map" instead of "optimizing the loop body").

## 3. The Evidence of Improvement (EOI)
Every successful loop must produce an EOI artifact in the report:
- **Before/After metrics**: (e.g., `800ms` -> `120ms`).
- **The "Smoking Gun"**: A clear identification of the bottleneck or vulnerability that was removed.
- **Verification Command**: A single shell command that a human can run to verify the result.

## 4. Anti-Drift Protection
Agents must not perform unrelated refactoring during an improvement loop.
- **Focus**: Only touch files directly related to the `--target`.
- **Cleanliness**: If an optimization requires "ugly" code, it must be encapsulated (e.g., in a `_hotPath` function) with a comment explaining why the trade-off was made.

## 5. Termination Criteria
A loop terminates when:
1.  The `--goal` is met.
2.  `--max-iterations` is reached.
3.  The agent achieves **diminishing returns** (improvement < 1% over two iterations).
4.  The agent identifies a "Hard Ceiling" (e.g., an OS limitation or hardware constraint).

## 6. Completion-Loop Mandates

Mandates 1–5 govern `RECURSIVE_IMPROVEMENT` and `ADVERSARIAL_HARDENING`.
The mandates below additionally govern `AUTONOMOUS_COMPLETION_LOOP`
(and any host-tool recurring loop composed from it). They exist because
completion loops fail differently from optimization loops: not by
regressing, but by **circling** — richer scaffolding around an unrun
gate, repeated probes of an unchanged environment, and parallel-state
sprawl that outgrows review capacity.

### 6.1 The Gate Ledger (progress is state transitions, not artifacts)

The loop's status file MUST maintain a gate table alongside its
narrative. Each row: `gate | state | identical-outcomes | last-change`.

- `state` is one of `unrun | fail | pass | blocked`.
- `identical-outcomes` counts consecutive cycles whose verification
  signature for that gate is unchanged (same skip reason, same failure
  signature — compare signatures, not prose).
- **Progress is a state transition** (`unrun→run`, `fail→pass`,
  `blocked→unblocked`). New artifacts that leave every gate in its
  prior state are not progress, regardless of count.

### 6.2 Anti-Circularity Rule (two identical outcomes → pivot or block)

If a gate records **2 consecutive identical outcomes**:

1.  **Stop**: no new scaffolding, tests, or status prose around that gate.
2.  **Pivot or block**: either change the approach (different access
    path, reduced permission surface, narrower gate — cf. the Rule of
    Three) or escalate to `blocked` naming the **precise decision or
    resource** needed (e.g., "which credential grants a disposable
    nonproduction role", not "database access").
3.  **Status-only churn is not a cycle deliverable.** Rewriting a prior
    outcome in new words, or re-verifying a gate whose inputs have not
    changed, does not count as the cycle's unit of work.

### 6.3 Environment Capability Cache (probe once, memoize)

Environment probes (database URL presence, container runtime
availability, network reachability of external APIs, sandbox
restrictions such as localhost-bind limits) are recorded with a
timestamp on first observation and **not re-probed until something
changed**: new credentials granted, sandbox lifted, explicit TTL
expiry, or a human reports a change. A cached `unavailable` is a fact
to plan around, not a finding to re-discover each cycle.

### 6.4 Parallel-State Budget (shepherd before spawning)

Before opening a new branch, worktree, or PR, the loop MUST check
existing parallel state: open loop-owned PRs, registered worktrees,
and in-flight exact-head CI runs.

1.  **Budget**: at most 3 open loop-owned PRs. Above budget, the
    cycle's job is shepherding (review, rebase, land, close) — not new
    work.
2.  **Settle-before-spawn**: no new feature branch while exact-head
    checks on the current head are still pending, unless the new work
    is independent and the operator explicitly overrides.
3.  **Scope-overlap check**: search open PRs for overlapping scope
    before branching. Duplicate-scope branches are closed, not merged.
4.  **Reviewability guard**: a dirty-path count or commits-ahead count
    that would make the next review unlandable forces a
    split-or-pause cycle instead of further commits onto the pile.

### 6.5 Harness-Failure Triage (classify red before acting)

Every red signal is classified **before** any retry:

| Class | Meaning | Response |
|-------|---------|----------|
| `product` | Code under test is wrong | Fix per `RESOLVE_FROM_REPORT` discipline |
| `harness-flake` | Timing, resource pressure, ordering — passes focused/standalone | Focused rerun once, then quarantine with evidence; never full-chain retry without new information |
| `environment-limit` | Sandbox or missing-resource restriction | Goes to the capability cache (6.3), not the retry queue |

A chained-suite failure that passes standalone is `harness-flake`
until proven otherwise. Treating it as `product` without that proof
is a defined loop error.

### 6.6 Credential-Safety Invariant

Read-only metadata commands (inventory lists, non-secret field gets,
firewall/trust-source reads) are allowed unattended. Any endpoint
that **returns credentials** (user lists, connection-string getters,
secret reveals) requires explicit per-invocation human authorization —
never inferred from a prior adjacent approval. A rejected
credential-adjacent command is recorded in the capability cache (6.3)
and not retried via an indirect route.
