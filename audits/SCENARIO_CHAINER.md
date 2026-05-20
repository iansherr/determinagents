# Scenario Chainer

## Purpose

Orchestrate complex, multi-step "stories" by chaining findings from independent audit reports. This agent moves beyond finding defects in isolation to finding **cascading failures**—where a sequence of individually minor bugs leads to a catastrophic outcome (e.g. data loss, privilege escalation, or UI state corruption).

Inspired by the Mythos framework and Mozilla's "Hardening Firefox" pipeline.

## Mode: Read-Only (Synthesizer)

This agent parses existing reports and generates a **Chain Specification**. It does not mutate code directly, but it provides the input for `HARNESS_CREATOR --mode=chain`.

## When to run

- After multiple static audits (`SECURITY_PENTEST`, `DATA_FLOW_TRACE`, `UX_DESIGN_AUDIT`) have produced findings.
- When `PICK_NEXT` recommends chaining due to high signal density across different categories.
- Before a major architectural change, to simulate "Attack Paths" or "Failure Journeys."

**Model tier**: `reasoning` — requires high-level architectural synthesis to connect disparate findings into a coherent stateful sequence.

## Output

`docs/reports/SCENARIO_CHAIN_<YYYY-MM-DD>.md`. This report contains the "Chained Hypotheses" and the technical requirements for the subsequent harness.

---

## Phase 0: Discovery

### 0.1 Report Inventory

```bash
# List recent reports to identify chaining candidates
ls -t docs/reports/*.md | head -20
```

### 0.2 Identify Cross-Category Signals

The agent reads the last 3-5 reports and looks for overlapping surface areas.
- **Surface Overlap**: A `UX` drift on the same page as a `Security` IDOR.
- **Data Overlap**: A `Data Flow` log that reveals an ID used in a `Stub` endpoint.
- **Logic Overlap**: An `Error Handling` gap in the same flow as a `Concurrency` risk.

---

## Phase 1: Chain Hypothesis Generation

For each overlapping surface, generate a **Chain Hypothesis**:

| Component | Finding A (Trigger) | Finding B (Pivot) | Finding C (Impact) |
|---|---|---|---|
| **Ex: Auth Bypass** | UX: Hidden "Debug" button visible | Data Flow: Button logs SessionID to localStorage | Security: IDOR accepts SessionID from localStorage |

**Success Criteria**: A successful chain must prove that the transition from A to B makes C reachable or more impactful.

---

## Phase 2: Technical Requirements

For the top 1-2 Chains, define the **Stateful Requirements**:

1.  **Initial State**: (e.g. "Logged in as User A, Database has record X")
2.  **Step 1 (Trigger)**: Specific action to exploit Finding A.
3.  **Step 2 (Pivot)**: Specific observation/capture to bridge to Finding B.
4.  **Step 3 (Impact)**: Final action that proves the "Catastrophe."

---

## Phase 3: Handover to Harness Creator

Generate the exact command to build the physics engine for this chain:

```bash
/determinagents harness --chain --report=docs/reports/SCENARIO_CHAIN_<DATE>.md
```

---

## Severity rubric (for the chain)

| Severity | Criteria |
|----------|----------|
| **P0** | The chain leads to unauthenticated RCE, total data loss, or global privilege escalation. |
| **P1** | The chain leads to unauthorized access to single-user data or significant UI state corruption. |
| **P2** | The chain is theoretically possible but requires unlikely environmental conditions. |

---

## Report template

```markdown
# Scenario Chain Report — <DATE>

## Summary
- Source Reports: [List of paths]
- Target Flow: <e.g. User Onboarding / Auth>
- Chains Identified: X

## Chained Hypothesis: <Title>
### The Story
[1-2 paragraphs describing the failure journey]

### The Path
1. **Trigger**: [Finding ID] - [Action]
2. **Pivot**: [Finding ID] - [Capture]
3. **Impact**: [Finding ID] - [Outcome]

### Technical Specs for HARNESS_CREATOR
- **Runtime**: <Playwright | Python | Docker>
- **State Requirement**: <DB setup, Auth keys>
- **Assertions**: <What defines a successful chain execution>

## Next steps
1. Run `/determinagents harness --chain --report=<THIS_PATH>`
2. Review generated `tests/harness/chain_*.spec.js`
```
