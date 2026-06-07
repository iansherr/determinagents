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
