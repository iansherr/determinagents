# Security Hunt (agentic vulnerability discovery)

## Purpose

Find real, reproducible vulnerabilities in a target file or function by giving an agent **execution capability** — the ability to build, modify, and run the project to verify or refute its own bug hypotheses. This is the agentic-harness paradigm that broke through the high-false-positive ceiling of static LLM security analysis.

The inner loop is intentionally simple: *"there is a bug in this part of the code, please find it and build a testcase."* The model proposes a hypothesis; the harness lets it test the hypothesis; only confirmed bugs reach the report.

This pattern is informed by Mozilla's [Behind the Scenes: Hardening Firefox](https://hacks.mozilla.org/2026/05/behind-the-scenes-hardening-firefox/) (May 2026), where it surfaced 271 latent bugs in a single Firefox release.

## Relationship to SECURITY_PENTEST.md

| | `SECURITY_PENTEST.md` | `SECURITY_HUNT.md` (this doc) |
|---|---|---|
| Mode | Static source-code analysis | Agentic with execution capability |
| Scope | Whole codebase, one pass | One file or function per session |
| Cost | Cheap, fast | Expensive, slow, requires build infrastructure |
| False-positive rate | Higher (no verification) | Lower (only confirmed bugs reported) |
| Best for | Surface scan, hardening review, no-infrastructure projects | Serious vulnerability discovery in mature codebases with build/test infra |

Run `SECURITY_PENTEST.md` for the surface scan. Run `SECURITY_HUNT.md` against the highest-risk files surfaced by that scan, and against any code touching trust boundaries (sandbox boundaries, IPC, parsers, JIT, deserialization, refcount/memory management).

## Mutating: yes

This doc is mutating. The agent will:
- Modify the project's source to insert testcases, instrumentation, or proof-of-concept payloads
- Compile, run, and possibly crash the project under test
- Write artifacts (testcases, repro scripts, sanitizer output) to the report directory

All execution happens in a workspace the user has explicitly designated as disposable. The doc never mutates the user's primary working tree.

## Prerequisites

1. **The project builds locally and tests run.** SECURITY_HUNT cannot work on a project the agent cannot compile.
2. **A disposable workspace.** Use a git worktree, dedicated branch, or container — not the user's main checkout. The agent will modify source code as part of its hypothesis testing.
3. **Sanitizers available** if the project supports them: AddressSanitizer (ASan), UndefinedBehaviorSanitizer (UBSan), ThreadSanitizer (TSan), MemorySanitizer (MSan). Sanitizers turn latent corruption into observable crashes — the foundation of "by defect class" severity.
4. **AUDIT_CONTEXT.md** with the `## SECURITY_HUNT` section configured (build commands, test commands, sanitizer flags, known-blocked patterns). See `specs/AUDIT_CONTEXT_TEMPLATE.md`.
5. **A specific target.** A file path or function name. Hunt sessions are not whole-codebase scans — they're depth-first per target.

If any prerequisite is missing, stop and surface that. Do not proceed without infrastructure; speculation without verification is exactly the failure mode this doc is designed to escape.

## When to run

- After `SECURITY_PENTEST.md` has identified high-risk surface area
- Against trust boundaries: sandbox/IPC, parsers, deserialization, JIT, memory management, refcount-heavy code
- After incidents, against the involved subsystem
- Continuously against high-churn files (the more code changes, the more latent bugs)
- Forecasted future use: against patches as they land in CI (scope=patch, see "Future" below)

## Time estimate

Open-ended; per-session typically 30 min to several hours depending on:
- Target complexity (a 200-line utility vs. a 5,000-line JIT compiler)
- Build/test cycle time
- How many hypotheses the agent investigates

Plan in target-sized chunks: one file per session, parallelize across sessions if you want coverage of many files.

## Output

`docs/reports/SECURITY_HUNT_<TARGET>_<YYYY-MM-DD>.md` — one per session. The report contains:

- **Confirmed findings** (bugs with reproducible testcase)
- **Attempted but blocked** (hypotheses that proved invalid because a defense thwarted them — positive signal about hardening)
- **Open questions** (hypotheses needing infrastructure the agent didn't have)

Confirmed findings include the testcase as a checked-in artifact under `docs/reports/hunt-artifacts/<REPORT_NAME>/` so the bug can be reproduced or used as a regression test.

---

## Phase 0: Discovery

### 0.1 Workspace check

```bash
# Refuse to run in the user's primary tree
git rev-parse --show-toplevel
git worktree list
git status --porcelain
```

Confirm the agent is in a disposable workspace. If unclear, ask the user explicitly: "I'll be modifying source. Confirm this checkout at `<PATH>` is disposable (worktree, branch, or container)?"

### 0.2 Build verification

From `AUDIT_CONTEXT.md` SECURITY_HUNT section, get the build command. Run it. Verify clean build before any hypothesis work — building must succeed first, or every later experiment is uninterpretable.

```bash
# Examples — actual command from AUDIT_CONTEXT
make build
cargo build --release
./mach build
go build ./...
```

### 0.3 Sanitizer availability

Determine which sanitizers are available and which are configured in this build:

```bash
# C/C++ — check for compiler flags
grep -rn 'fsanitize=address\|fsanitize=undefined\|fsanitize=thread' \
  CMakeLists.txt Makefile* configure* 2>/dev/null

# Rust
grep -rn 'sanitizer' Cargo.toml .cargo/config* 2>/dev/null

# Go has built-in race detector
echo "Run with: go test -race ./..."
```

If no sanitizers are configured, propose enabling them for the hunt session (still in the disposable workspace). Without sanitizers, defect-class detection is fragile — a UAF that doesn't trigger a visible crash will be missed.

### 0.4 Target confirmation

The user-supplied target (file or function) must exist. Verify:

```bash
[ -f "$TARGET_FILE" ] || { echo "Target not found: $TARGET_FILE"; exit 1; }
```

For function targets, locate the file:

```bash
grep -rn "func\|fn\|def\|function $TARGET_NAME" --include='*.go' --include='*.rs' \
  --include='*.py' --include='*.c' --include='*.cpp' .
```

### 0.5 Read AUDIT_CONTEXT

From the SECURITY_HUNT section:
- **Build/test commands** (used in Phases 0.2, 3.x)
- **Known-blocked attack patterns** (defenses that already prevent certain bug classes — don't re-attempt)
- **Past confirmed bugs in this target** (dedup input)
- **Trust boundaries in this codebase** (where attacker-controlled input meets privileged code)
- **Sensitive paths** (areas with elevated severity calibration)

---

## Phase 1: Hypothesis generation

Read the target file. Build a list of bug-class hypotheses appropriate to the language and code shape. Use this rubric, not exhaustive enumeration:

| Bug class | Triggers / patterns to look for |
|-----------|--------------------------------|
| **Use-after-free (UAF)** | Refcount manipulation, callback teardown, async lifetime, raw pointers across yield points, event handler unregistration |
| **Out-of-bounds (OOB) read/write** | Hand-rolled bounds checks, integer arithmetic on indices, manual buffer sizing, off-by-one in loops |
| **Type confusion** | Polymorphic deserialization, JIT speculation, NaN-tagged values, union types, dynamic dispatch through cast |
| **Integer overflow with security impact** | Bitfield clamping, size-with-multiply, container counts in fixed-width types |
| **Race conditions** | Shared mutable state across threads/IPC, refcount manipulation, double-fetch from untrusted memory |
| **Sandbox boundary violations** | Trust-level confusion (data from untrusted process treated as trusted), incomplete validation at boundary |
| **Resource exhaustion / DoS** | Unbounded recursion, unbounded allocation driven by attacker input, lock contention |
| **Logic bugs in security-critical code** | Auth checks with subtle bypass, validation skipped on certain code paths, TOCTOU |

Per hypothesis, write down: **what** (bug class), **where** (file:line), **why** (specific code construct that suggests it), **how to test** (sketch of testcase). Keep the list focused — depth over breadth.

---

## Phase 2: Per-hypothesis verification loop

For each hypothesis from Phase 1, in order of confidence:

### 2.1 Build a minimal testcase

Write the smallest possible testcase that would trigger the suspected bug. This may require:
- Adding a unit test
- Modifying source to expose an internal API
- Building a fuzz seed
- Crafting a network packet, file, or input string
- Patching the project to insert a hostile caller (allowed in disposable workspace)

For sandbox-escape-class bugs specifically: it is acceptable for the testcase to modify source code that runs **only in the would-be-compromised context** (e.g., inside the sandbox), simulating an attacker who has already compromised that layer. This mirrors Mozilla's bounty rule: simulating a compromised sandboxed process is a fair starting point for testing escape paths.

### 2.2 Execute under sanitizers

```bash
# Examples — actual command from AUDIT_CONTEXT
ASAN_OPTIONS=detect_leaks=1 make test
RUSTFLAGS="-Z sanitizer=address" cargo test
go test -race ./...
```

Observe outcome:

| Result | Interpretation |
|--------|----------------|
| **Sanitizer error** (UAF, OOB, race, etc.) | Bug confirmed at defect-class severity. Capture full sanitizer output. |
| **Crash without sanitizer signal** | Bug confirmed but defect class unknown. Investigate — could still be exploitable. |
| **Test passes; expected behavior** | Hypothesis was wrong, OR a defense thwarted it. Move to 2.3. |
| **Test passes; unexpected behavior** | Investigate — partial hypothesis, may need refinement. |
| **Build fails** | Testcase is malformed; iterate. Don't claim a bug from a broken build. |

### 2.3 Distinguish "no bug" from "blocked by defense"

When a hypothesis fails to trigger, ask: **was the bug not present, or was it blocked by an existing defense?** Read the code path. If a sanitizer/check/freeze/validation prevented the bug, that's a *positive finding* about the defense — log it under "Attempted but blocked" in the report. This is signal that previous hardening work is paying off.

Mozilla calls this out specifically: observing thwarted attempts on prototype-pollution vectors validated their architectural decision to freeze prototypes. The same applies to any defense-in-depth measure.

### 2.4 Triage confirmed bugs

For each confirmed bug:

1. **Dedup against AUDIT_CONTEXT** known bugs and past reports in `docs/reports/`. If already known, mark and move on.
2. **Classify severity by observable defect class**, NOT by whether you can build an end-to-end exploit:

| Severity | Defect class |
|----------|--------------|
| **P0** | UAF, OOB read/write, double-free, type confusion, JIT mis-optimization, integer overflow with memory-safety impact, sandbox-boundary violation |
| **P1** | Race condition with state corruption, info leak (memory contents to attacker-readable surface), refcount underflow, lifetime confusion across IPC |
| **P2** | Assertion failure on attacker input, denial-of-service via resource exhaustion, partial-state corruption with bounded blast radius |
| **P3** | Null deref where mitigations make it non-exploitable, divide-by-zero, unbounded log spam |

This rubric is from Mozilla's threat model. Rationale: gating severity on exploitability requires building exploits, which is expensive. Gating on defect class is cheap, conservative, and reduces false negatives. A UAF you can't currently exploit may be exploitable by a more clever attacker tomorrow.

3. **Capture a permanent regression artifact**: copy the testcase to `docs/reports/hunt-artifacts/SECURITY_HUNT_<TARGET>_<DATE>/<finding-N>/` so the bug remains reproducible after the disposable workspace is destroyed.

### 2.5 Iterate

Continue through hypotheses until exhausted, or stop early if the user requests, or stop on hitting a time/budget limit.

---

## Phase 3: Report

Produce `docs/reports/SECURITY_HUNT_<TARGET>_<YYYY-MM-DD>.md` per `specs/FORMAT.md`, with these audit-specific sections:

- **Target** — file and/or function under hunt
- **Build/exec environment** — branch, commit SHA, sanitizers used, build commands
- **Confirmed findings** — table by severity, with `repro:` link to the artifact directory
- **Attempted but blocked** — bug-class attempts that were thwarted, with the defense that blocked them. Treat as positive signal.
- **Open questions** — hypotheses that needed infrastructure the agent didn't have (e.g., a custom fuzzer, a proprietary tool); flag for human follow-up.
- **Patterns observed** — meta-analysis (e.g., "this file uses raw pointers across async boundaries pervasively; consider migration to safer abstractions")

Include the universal sections (severity rubric, next steps) per `specs/FORMAT.md`.

---

## Severity rubric (this audit)

See Phase 2.4. The rubric is **observable-defect-class-based**, not exploitability-based:

- **P0**: defect class with established memory-safety impact (UAF, OOB, type confusion, JIT bug, integer overflow into memory ops, sandbox boundary failure)
- **P1**: races with state corruption, info leaks, refcount/lifetime issues across trust boundaries
- **P2**: DoS, assertion failures on attacker input, partial-state corruption
- **P3**: bugs requiring multiple mitigations to bypass; non-security correctness issues

Adopting this rubric reduces both triage cost and false negatives. A finding that is theoretically exploitable but currently unreachable is still P-class — defense in depth assumes any of these could be exploitable with sufficient effort.

---

## Implementation rules

- **One target per session.** Do not try to hunt across the whole codebase in one run; the harness loses focus and the report becomes useless.
- **Verify or discard.** A hypothesis without an executed testcase does not become a finding. The whole point of agentic hunting is escaping the high-false-positive trap of static prompting.
- **Stay in the disposable workspace.** Never modify source in the user's primary tree. If the user gives you the wrong path, refuse and ask.
- **Capture artifacts immediately.** A bug only matters if it stays reproducible. Copy testcases to the artifacts directory before tearing down the workspace.
- **Defect-class severity, not exploitability.** Don't downgrade a UAF because "you couldn't build an exploit." That's the resource trap Mozilla explicitly avoids.
- **Log blocked attempts.** "I tried X and it didn't work because Y" is a finding, not a non-finding. Defense validation is part of the value.
- **Stop and surface infrastructure gaps.** If you can't build, can't run sanitizers, or can't reach a code path because of missing tooling, say so. Don't fake findings to fill the report.

---

## Anti-patterns

- **Static-only "audit" disguised as hunt.** Reading the code and producing a list of suspicions, with no testcases, is `SECURITY_PENTEST.md`. Don't call it a hunt.
- **Speculative bug reports.** "This *could* be a UAF" without an executed testcase is exactly the AI-slop pattern that hardened maintainers against AI security reports in the first place. Mozilla's pipeline succeeded because *only confirmed* bugs reach the report.
- **Severity inflation by claimed exploitability.** "I think this is exploitable" is not a P0 escalator. The defect class is the rubric.
- **Hunting in the user's primary checkout.** Modifying source to test hypotheses on a tree the user is also working in is destructive. Disposable workspace, always.
- **One giant report covering 50 files.** Scope per session is one target. Multi-target campaigns are multiple sessions.

---

## Composition

- **Input from**: `SECURITY_PENTEST.md` report (high-risk surface area to target), or AUDIT_CONTEXT.md sensitive-paths list, or human judgement
- **Output to**: `RESOLVE_FROM_REPORT.md` for fix workflow. SECURITY_HUNT findings are typically high-severity; resolve in priority order.
- **Pair with**: `TESTING_CREATOR.md` Tier 1 (Adversarial) — turn each confirmed finding into a permanent regression test so the bug class can't reappear without breaking the suite.

The full chain for a security-focused engagement:

```
SECURITY_PENTEST → identifies high-risk surface
SECURITY_HUNT (per file)  → produces verified findings
RESOLVE_FROM_REPORT → fixes findings (with approval per fix)
TESTING_CREATOR Tier 1  → adds regression tests
SECURITY_HUNT re-run  → confirms clean
```

---

## Future scope: patch-based hunting

Mozilla forecasts patch-based scanning — invoking a hunt against the diff in a PR, rather than a whole file — as the next evolution. Easier to integrate with CI, scoped to recent change, faster per run.

When this becomes a documented pattern in the library, it'll be `scope=patch` on this same doc, taking a base ref + head ref instead of a target file. For now, file-scope is the documented path.

---

## Credits

Pattern and severity rubric drawn from Mozilla Security's [Behind the Scenes: Hardening Firefox](https://hacks.mozilla.org/2026/05/behind-the-scenes-hardening-firefox/) (May 2026), which describes the agentic-harness pipeline that surfaced 271 latent bugs in a single Firefox release. The inner-loop framing — *"there is a bug in this part of the code, please find it and build a testcase"* — is theirs verbatim.
