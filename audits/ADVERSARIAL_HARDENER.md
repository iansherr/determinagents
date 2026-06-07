# Adversarial Hardener

## Purpose

Implement an autonomous Red Team/Blue Team loop to proactively discover and patch vulnerabilities, prompt injections, or edge-case failures in AI systems and critical logic paths. This agent generates adversarial inputs, observes failures, and autonomously patches the system to harden it against the discovered attack vectors.

Inspired by recursive self-improvement and adversarial training models.

## Mode: Mutating

**Protocol**: This audit follows the [Recursive Self-Improvement Protocol](../specs/LOOP_PROTOCOL.md).

This agent **mutates** the codebase (system prompts, validation logic, or testing harnesses). It requires a disposable workspace (git worktree, branch, or container).

## When to run

- After adding a new LLM capability, prompt, or tool.
- When `SECURITY_PENTEST` identifies injection risks but lacks concrete test cases.
- To proactively harden a subsystem (e.g., input parsers, IPC handlers) against edge cases.

**Model tier**: `reasoning` — requires adversarial thinking (Red Team) and architectural patching (Blue Team).

## Flags

- `--target="<path/to/component>"`: The specific file or module to harden (e.g., `core/llm/prompt.js`).
- `--harness="<command>"`: The command to execute the test suite or evaluation (e.g., `npm run eval-llm`).
- `--max-iterations=<N>`: Limit the number of Red/Blue cycles. Default: 5.

## Output

1. **Hardened Code**: Commits patching the identified vulnerabilities.
2. **Golden Tests**: New test cases added to the test suite capturing the adversarial vectors.
3. **Hardening Report**: `docs/reports/ADVERSARIAL_HARDENING_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery & Baseline

### 0.1 Setup
- Verify disposable workspace.
- Identify the target component and current test harness.
- Run the baseline harness to ensure the target is currently passing all existing tests.

---

## Phase 1: Red Team (Generation)

Adopt an adversarial mindset.
- Analyze the target component's expected input structure and constraints.
- Generate 5-10 adversarial test cases. These should include:
  - **Prompt Injection**: "Ignore previous instructions..."
  - **Schema Evasion**: Malformed JSON, deeply nested structures, unexpected types.
  - **Boundary Pushing**: Extremely large payloads, CJK characters, control characters.
- Add these test cases to the test harness (or a temporary evaluation script).

---

## Phase 2: Execution (Attack)

- Run the harness with the newly added adversarial inputs.
- Log which inputs successfully bypassed validation, caused crashes, or elicited disallowed behavior.
- If all adversarial inputs are blocked safely, the component is hardened against this iteration's vectors. Proceed to Phase 4.

---

## Phase 3: Blue Team (Patching)

For every successful attack from Phase 2:
- Analyze *why* the attack succeeded (e.g., missing regex anchor, insufficient context window, lack of type validation).
- Formulate a patch for the target component (e.g., harden the system prompt, add Zod schema validation, implement sanitization).
- Apply the patch.
- Re-run the harness.
- **Success**: The attack is now blocked, AND the baseline functionality remains unbroken.
- **Failure**: The attack still succeeds, or baseline functionality broke. Revert and try a different patch strategy.

*Repeat Red/Blue cycles until `--max-iterations` is reached or the system is robust against generated attacks.*

---

## Phase 4: Finalization

- Commit the hardened target component.
- Commit the successful adversarial test cases permanently to the repository as "Golden Tests."
- Generate the final report.

---

## Severity rubric (for the vulnerabilities found)

| Severity | Criteria |
|----------|----------|
| **P0** | Adversarial input causes RCE, full prompt extraction, or unauthenticated data access. |
| **P1** | Adversarial input causes application crash (DoS), partial data leakage, or circumvents primary validation. |
| **P2** | Adversarial input produces malformed output or unexpected but safe behavior. |

---

## Report template

```markdown
# Adversarial Hardening Report — <DATE>

## Summary
- **Target**: `<Target Component>`
- **Iterations Run**: X / Y max
- **Vulnerabilities Found**: X
- **Vulnerabilities Patched**: Y

## Attack Vectors Discovered
### Vector 1: <Name/Type>
- **Payload**: `<Adversarial Input>`
- **Impact**: <What went wrong>
- **Severity**: P0/P1/P2
- **Blue Team Patch**: <How it was fixed (e.g., updated system prompt to reject nested commands)>

## Next steps
- Review the new Golden Tests added to the test suite.
- Merge the hardened component into the main branch.
```
