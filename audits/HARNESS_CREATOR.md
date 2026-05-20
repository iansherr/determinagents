# Harness Creator

## Purpose

Deterministically generate verification harnesses (Playwright scripts, Docker runners, fuzzing suites, or fault-injection skeletons) to prove or refute findings from static audit reports. 

Instead of prose-based "Harness path" suggestions, this agent implements the **executable starting point**. It follows the principle: *Simple prompt + good harness > clever prompt + no harness.*

## Mode: Mutating

This agent **mutates** the codebase by creating new test files, configuration, and runners. It requires a disposable workspace (git worktree, branch, or container).

## When to run

- After a static audit (UX, Security, Docs Drift, etc.) produces findings that require behavioral verification.
- During project initialization (`--mode=baseline`) to set up generic testing infrastructure.
- When an agent is "stuck" in a static reasoning loop and needs a physics engine (harness) to test hypotheses.
- To install permanent regression coverage for complex behaviors (concurrency, data integrity).

**Model tier**: `reasoning` — needs to understand the project's build system and the specific defect class to generate a valid testcase.

## Flags

- `--report=<path>`: The audit report containing findings to be harnessed.
- `--mode=baseline`: (Optional) Initialize the project's harness infrastructure (config, boilerplate, smoke tests) without a report.

## Output

1. **Harness Artifacts**: Executable files in the project's `tests/`, `simulation/`, or `harness/` directory.
2. **Harness Report**: `docs/reports/HARNESS_CREATOR_<YYYY-MM-DD>.md` documenting the generated suite and how to run it.

---

## Phase 0: Discovery

### 0.1 Workspace & Report

- Verify disposable workspace (Phase 0.1 per `specs/FORMAT.md`).
- Locate the target audit report (passed via `--report=<path>`).
- Inventory existing test infrastructure (Phase 0.1 per `audits/TESTING_CREATOR.md`).

### 0.2 Defect Class Identification

Read the report. For each finding to be harnessed, classify the verification strategy:
- **Visual/UX** → Playwright / ComputedStyle / Screenshot-diff.
- **Data Flow/Integrity** → DB transaction logging / Wire capture / Integrity check.
- **Security** → Fuzzing / RBAC matrix / Attestation challenge.
- **Docs/Setup** → Docker-based cleanroom runner.
- **Concurrency/Chaos** → Multi-node simulation / Fault injection.

---

## Phase 1: Skeleton Generation

For the identified strategy, generate the **minimal reproducible skeleton**.

### 1.1 Ground Truth Protocol (Hard Enforcement)
To ensure the harness provides genuine verification and doesn't just "spot-check" what the agent already saw, the generated code **MUST** follow these structural rules:

1.  **Iterative Loop Requirement**: Assertions **MUST NOT** be hardcoded for specific variables (e.g. `expect(brand).toBe('#hex')`). Instead, the harness **MUST** load the Canonical Manifest (from DESIGN.md or the audit report) and loop through every item, asserting its state programmatically.
2.  **The Negative Grep Phase**: The agent **MUST** run a discovery command (e.g. `grep -rE '--[a-z0-9-]+'`) to find all variables in the codebase and compare them against the manifest. Any variable in the code but **not** in the manifest MUST be included in the harness report as an "Orphan/Ghost" finding.
3.  **Prohibited Shortcuts**: Do **NOT** generate a harness that only tests a subset of tokens you "spotted" during discovery. The harness is a validator for the *entire* manifest.
4.  **Visibility Assertion (UI only)**: Any UI harness **MUST** assert that elements are **visible** to the user (`.toBeVisible()`), not just present in the DOM. This prevents "Ghost UI" false-positives where an app creates a window but fails to show it.
5.  **Boot-Sequence Watcher**: Any harness that launches an app/service **MUST** capture and check console/stderr for the first 10 seconds of startup. Errors during the boot sequence outrank subsequent test failures.
6.  **Artifact-First Testing**: Any harness verifying a distribution (Electron, Docker, Binaries) **MUST** execute the actual artifact (e.g. the `.app` or `.exe`) rather than the source code.

### 1.2 Harness Intelligence (Resilience Rules)
To ensure reliability and minimize noise, the generated harness **MUST** include:
...

- **Config**: Add necessary dependencies to `package.json`, `requirements.txt`, etc. (but do not run install unless in a container).
- **Boilerplate**: Generate the test harness entry point (e.g., `tests/harness/ux_drift_verify.spec.ts`).
- **Targeting**: Hardcode the specific endpoints, files, or states identified in the report findings.

---

## Phase 2: Hypothesis → Experiment

For the top P0/P1 findings in the report, implement the **inner loop** logic:

1. **Setup**: Code to reach the state (e.g., "Log in as Admin, navigate to /settings").
2. **Action**: The trigger (e.g., "Set primary color to #hex").
3. **Assertion**: The verification (e.g., "Assert computed background-color matches").

If the implementation is complex, the agent generates a **high-fidelity starting point** with clear `TODO: [logic]` comments and a README on how to run it, guiding a subsequent agent or human.

---

## Phase 3: Verification Checkpoint

Attempt to run the generated harness (if the environment allows).
- **Pass**: The harness is valid (even if the finding is refuted).
- **Fail**: The harness has syntax/setup errors; iterate on the generator.

---

## Phase 4: Integration & Handover

- Commit the harness artifacts (separate commit from fixes).
- Provide the exact shell command to run the harness.
- Update the source report with a link to the generated harness.

---

## Strategy Blueprints (High-Value Gaps)

When the audit report identifies a high-value gap, use these blueprints as the **Starting Point**:

### B1. DB Fault Scenario (SQLite/PG)
- **Harness**: A script that manually corrupts the DB or locks it before running the app.
- **Logic**: `sqlite3 db.sqlite "PRAGMA journal_mode=DELETE; ..."`, then attempt an app operation.
- **Assertion**: App must return a graceful error/retry, **not** crash or show raw SQL errors.

### B2. API Fault Injection (Adapters)
- **Harness**: A proxy or mock-server (e.g. `nock`, `msw`, or a Python `httpretty` script).
- **Logic**: Simulate `HTTP 429` (Rate Limit) or a 30s timeout for a third-party service (Asana, CalDAV).
- **Assertion**: App must trigger the "Offline/Degraded" UI and retry with exponential backoff.

### B3. Pathological Fuzzing (Parser)
- **Harness**: A loop that feeds a "Junk Drawer" of pathological strings into the parser.
- **Logic**: `['\u0000', 'A' * 10240, '{"unclosed": "brace"', 'invalid-date-2026-99-99']`.
- **Assertion**: Parser must return an "Invalid" result object, **not** throw an unhandled exception or hang the event loop.

### B4. Memory Leak Detection
- **Harness**: A long-running loop (100+ iterations) of a core sync function.
- **Logic**: Record `process.memoryUsage().heapUsed` before and after the loop.
- **Assertion**: Heap growth after GC should be `< 5%` of the total throughput.

---

## Severity rubric (for the harness itself)

| Severity | Criteria |
|----------|----------|
| **P0** | Harness is broken: doesn't run, syntax errors, or hangs. |
| **P1** | Harness runs but produces false positives (flags the wrong things). |
| **P2** | Harness is manually intensive: needs significant hand-editing before first run. |
| **P3** | Documentation drift: the harness README doesn't match the code. |

---

## Report template

```markdown
# Harness Creator Report — <DATE>

## Summary
- Source Report: <path>
- Findings processed: X
- Harness Type: <Playwright | Docker | Fuzzing | etc.>
- Location: <path to generated files>

## Generated Artifacts
| File | Purpose | Status |
|---|---|---|

## Execution Command
```bash
# How to run the harness
npm run test:harness
```

## Handover for Next Agent
1. Use the generated skeleton at `<path>`.
2. Focused task: [Specific instructions for the next loop].
3. Success criteria: [Expected outcome].

---

## Anti-patterns

- **Spot-Checking**: Generating a harness that only tests 3-4 "obvious" variables you saw in the code. This is a false verification. The harness MUST loop through the manifest.
- **The Test God-File**: Creating a single massive harness script to verify 20 unrelated findings. This makes the harness fragile and hard to debug. Generate targeted harnesses or cohesive suites.
- **Silent Setup Failures**: Assuming the environment is ready (e.g., Docker running) without a Phase 0.1 check.
- **Baking Content**: Inlining findinds into the harness instead of referencing the report artifacts.

## Recommendations
1. ...
```
