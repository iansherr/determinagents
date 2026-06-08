# Loop Bootstrap & Discovery

## Purpose

Guided UX to set up improvement loops. Scans the repo, suggests targets, and writes a persistent loop registry (`LOOPS.md`).

## Mode: Interactive / Scaffolding

This agent acts as a setup wizard. It scans code, converses with the user, and writes configuration files.

## When to run

- When you want to introduce continuous autonomous improvement to a project but don't know where to start.
- When you have existing tests or benchmarks and want to wire them up to `LOOP_ORCHESTRATOR` or `RECURSIVE_IMPROVEMENT`.

**Model tier**: `reasoning` — requires analyzing complex codebases to identify optimization targets and conversational ability to guide the user.

## Output

1. **Conversational Guide**: The agent explains loops, proposes targets, and asks the user for confirmation.
2. **Loop Registry**: `docs/determinagents/LOOPS.md` — a persistent configuration file tracking the project's autonomous loops.

---

## Phase 0: Education & Discovery

### 0.1 Brief the User
Start by giving the user a 2-sentence explanation of what is happening:
> "I am going to help you set up Recursive Improvement Loops. These allow an agent to autonomously run tests, generate hypotheses, write code, and verify improvements without human intervention."

### 0.2 Scan the Repository
Identify what the project currently uses for testing, benchmarking, or linting.
- Look at `package.json`, `Makefile`, `Cargo.toml`, `tox.ini`, etc., for scripts like `test`, `bench`, `perf`, `fuzz`.
- Look for standard test directories (`tests/`, `spec/`, `e2e/`).
- Look for `docs/reports/` for past audits that highlighted regressions or performance issues.

---

## Phase 1: Propose Loops

Analyze the discovered harnesses and propose 2-4 concrete loops.
A good loop needs a **Target** (what to improve), a **Harness** (the deterministic command that verifies it), and a **Goal** (what success looks like).

*Examples to propose:*
- **Performance**: "Make `npm run bench:parser` execute 20% faster."
- **Hardening**: "Run `npm run test:e2e` while I try to inject fault/chaos scenarios to find unhandled edge cases."
- **Refactoring**: "Fix the TypeScript `any` types in `src/api/` while ensuring `npm test` still passes."

Present these options to the user in a clear list and ask:
> "Which of these loops would you like to memorialize? You can pick from this list, or suggest your own."

**Wait for the user's response before proceeding to Phase 2.**

---

## Phase 2: Memorialize the Loops

Once the user approves or defines their loops, create or update the persistent registry file at `docs/determinagents/LOOPS.md`.

Use the following exact format so `LOOP_ORCHESTRATOR.md` can parse it:

```markdown
# Autonomous Improvement Loops

This file defines the deterministic loops that `LOOP_ORCHESTRATOR` or `RECURSIVE_IMPROVEMENT` can run autonomously to improve this codebase.

## Active Loops

| ID | Target Area | Harness Command | Loop Type | Goal |
|---|---|---|---|---|
| `loop-01` | `src/parser.ts` | `npm run bench:parser` | `RECURSIVE_IMPROVEMENT` | Improve parsing speed by 20% |
| `loop-02` | `src/api.js` | `npm test -- api.spec.js` | `ADVERSARIAL_HARDENER` | Discover unhandled edge cases in input validation |

## Instructions
To run all active loops sequentially, run:
`/determinagents loop-orchestrator`

To run a specific loop manually, run:
`/determinagents recursive --goal="<Goal>" --harness="<Harness Command>"`
```

---

## Phase 3: Handover

Conclude the setup by explaining to the user how to trigger the work.
> "Your loops are now memorialized in `docs/determinagents/LOOPS.md`. 
> 
> You can trigger the orchestrator to start running them sequentially by using:
> `/determinagents loop-orchestrator`
>
> Or, you can manually run a single improvement loop anytime with:
> `/determinagents recursive --goal="..." --harness="..."`"
