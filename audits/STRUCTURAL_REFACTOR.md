# Structural Refactor

## Purpose

Take a `STRUCTURAL_ENTROPY` report and execute its seam proposals — one god-file at a time, one seam at a time, one commit per extraction. Mutating.

This doc is a **specialization of `RESOLVE_FROM_REPORT.md`** for structural-entropy reports. Most of the discipline (disposable workspace, per-finding triage, shorthand approval keys, commit format, anti-patterns) is identical and is **not duplicated here** — defer to `RESOLVE_FROM_REPORT.md` for that machinery. This doc adds three things RESOLVE does not have:

1. A **contract-before-code gate**: each seam's interface is written and approved before any code moves.
2. A **per-seam (not per-finding) loop**: one god-file = one finding = many seams = many commits.
3. **Dependency-graph artifacts**: before/after snapshots per file, so the reduction in coupling is observable, not asserted.

## When to run

After a `STRUCTURAL_ENTROPY` report exists in `docs/reports/` and the seam proposals have been reviewed. Not appropriate for ad-hoc "clean this up" requests — without the report, the seams haven't been planned and this loop has nothing to consume.

**Model tier**: `reasoning`

Rationale: contract design and seam ordering across many extractions is multi-step architectural synthesis, not pattern-matching. Underpowering here produces the failure mode the original audit was supposed to prevent.

## Time estimate

Open-ended. One god-file typically takes 1–3 sessions, with 2–6 seams per file and one commit per seam. Plan in batches: one file per session is a reasonable default.

## Output

- One commit per seam extracted.
- One commit per file completing the seam set (test the file as a whole, update imports, remove the now-vestigial god-file responsibilities).
- A `## Refactor log` section appended to the structural-entropy report.

- Dependency-graph artifacts under `docs/reports/refactor-artifacts/<report-name>/<file-slug>/`: `before.txt`, `after.txt`, and one `seam-N.txt` per extraction.

## Prerequisites

- A `STRUCTURAL_ENTROPY` report at `docs/reports/`.
- Disposable workspace per `RESOLVE_FROM_REPORT.md` Phase 0.1.
- Tests run locally. If tests do not cover the god-file, run `TESTING_CREATOR.md` Tier 1 against it **first** — moving code without coverage is exactly the regression vector this audit is supposed to prevent. Document the decision in `AUDIT_CONTEXT.md` if tests genuinely cannot be added.

---

## Phase 0: Deferred to RESOLVE_FROM_REPORT

Run Phases 0.1 (working-tree check), 0.2 (locate report), 0.3 (parse), 0.4 (staleness), and 0.5 (AUDIT_CONTEXT) exactly as defined in `audits/RESOLVE_FROM_REPORT.md`. Then return here.

One addition specific to this audit: in 0.3, confirm the report is a `STRUCTURAL_ENTROPY` report — if it's another audit's report, stop and recommend `RESOLVE_FROM_REPORT.md` instead.

---

## Phase 1: Triage god-files (not findings)

Each god-file in the report is one finding with multiple seams. Triage is per file, not per seam.

Present to the user:

```
Report: docs/reports/STRUCTURAL_ENTROPY_2026-05-12.md

God-files:
  P0 #1 src/components/agent-workspace.tsx   5 responsibilities, 3 seams
  P1 #1 src/api/chat-pane.tsx                4 responsibilities, 4 seams
  P1 #2 lib/pi-runtime/executor.ts           3 responsibilities, 2 seams
  P2 #1 src/services/storage.ts              3 responsibilities, 1 seam

Plan: address P0 #1 this session (3 seams, ~1–2 hours).
P1 entries deferred to follow-up sessions.

Proceed? [y/n/edit]
```

One file per session is the default. A user can scope wider, but the loop is still file-by-file inside the session — never interleaved seams across files.

---

## Phase 2: Per-seam loop

For each seam in the selected file, in the order proposed by the report (lowest coupling first):

### 2.1 Snapshot

Before touching the file, capture the dependency baseline:

```bash
FILE="<target file>"
SLUG="<file-slug>"
DIR="docs/reports/refactor-artifacts/<report-name>/$SLUG"
mkdir -p "$DIR"

# Fan-in
grep -rEn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  "from\s*['\"].*${FILE%.*}['\"]" . > "$DIR/before.txt"

# Function-level structure
awk '/^(export\s+)?(async\s+)?(function|const\s+\w+\s*=\s*(async\s*)?\()/{print NR, $0}' "$FILE" >> "$DIR/before.txt"
```

Only on the first seam per file. Subsequent seams update `before.txt` only if the file structure has materially shifted.

### 2.2 Re-read the seam proposal

The report's seam proposal is a starting point, not a recipe. Re-read the actual lines named in the seam. The agent verifies:

- The lines still contain the responsibility named (god-files churn; the report may be days old).
- The proposed destination does not already exist with a conflicting shape.
- The proposed contract still fits the consumer-side usage.

If any of these have drifted, re-plan the seam fresh and surface the divergence to the user before proceeding.

### 2.3 Contract gate — write the interface first

**No code moves until the contract is approved.**

The agent writes the destination file with **only the interface** — types, function signatures, hook return shape — and a body that is either an empty stub or a re-export of the existing implementation:

```ts
// src/hooks/useWorkspacePersistence.ts (Seam 1 contract)

export interface WorkspacePersistenceState {
  workspace: WorkspaceShape | null
  setWorkspace: (next: WorkspaceShape) => void
  isHydrated: boolean
}

export function useWorkspacePersistence(): WorkspacePersistenceState {
  // TODO Seam 1: extract from agent-workspace.tsx lines 412–438, 501–522, 1104–1128
  throw new Error("not yet extracted")
}
```

Then present the contract to the user with the shorthand from `RESOLVE_FROM_REPORT.md` Phase 2:

```
Seam 1 of 3: localStorage persistence → src/hooks/useWorkspacePersistence.ts

  Contract:
    interface WorkspacePersistenceState {
      workspace: WorkspaceShape | null
      setWorkspace: (next: WorkspaceShape) => void
      isHydrated: boolean
    }
    function useWorkspacePersistence(): WorkspacePersistenceState

  Consumer site (agent-workspace.tsx):
    const { workspace, setWorkspace, isHydrated } = useWorkspacePersistence()
    // replaces lines 412–438, 501–522, 1104–1128

  Out-of-scope but worth flagging: lines 522–540 also read localStorage
  but for a different key (telemetry). Treat as a separate seam, not
  bundled with this one.

  [y] approve contract  [d] diff the stub  [e] edit  [s] skip  [i] invalid  [q] quit
```

The user approves the *contract*, not the implementation. If they edit, iterate until approved. The contract is then committed as its own commit:

```
refactor(<file-slug>): introduce <hook/service/module> contract (seam N)

Resolves STRUCTURAL_ENTROPY_<DATE>:<SEVERITY> #<FILE> seam <N>
Contract-only commit; implementation in follow-up commit.
```

### 2.4 Move the code

Implement the destination file's body by moving (not copying) the named lines from the god-file. Update the god-file's consumer sites to call through the contract.

The diff for this step touches exactly two files: the new destination, and the god-file. If a third file changes, that's scope creep — surface it as a new seam or new finding.

Run tests. If they fail:
- **Tests that exercise the moved code**: fix the move (the contract or its implementation is wrong). Re-plan the contract if needed.
- **Tests unrelated to the moved code**: pre-existing breakage; surface it and ask whether to proceed.
- **No tests cover this code**: stop and surface — this is the prerequisite violation flagged in Phase 0. Do not proceed without coverage; the regression risk is exactly what the audit was supposed to mitigate.

Commit:

```
refactor(<file-slug>): extract <responsibility> to <destination> (seam N)

Resolves STRUCTURAL_ENTROPY_<DATE>:<SEVERITY> #<FILE> seam <N>
<2-3 sentences: what moved, why this seam came first, what the contract is>
```

### 2.5 Per-seam artifact

```bash
# After commit:
git show --stat HEAD > "$DIR/seam-${N}.txt"
echo "---" >> "$DIR/seam-${N}.txt"
echo "Contract:" >> "$DIR/seam-${N}.txt"
# (paste the interface block)
```

### 2.6 Annotate the report

Append to the report's `## Refactor log` section:

```markdown
## Refactor log

### 2026-05-13 — session by Claude

#### `src/components/agent-workspace.tsx`

| Seam | Responsibility | Destination | Contract commit | Move commit |
|---|---|---|---|---|
| 1 | localStorage persistence | `src/hooks/useWorkspacePersistence.ts` | abc1234 | def5678 |
| 2 | SSE stream handling | `src/lib/agentStream.ts` | ghi9abc | jkl2def |
| 3 | Toolbar JSX | `src/components/WorkspaceToolbar.tsx` | — | — (deferred) |
```

Loop to the next seam.

---

## Phase 3: File-level close-out

After the last seam for a file:

### 3.1 Re-snapshot

```bash
grep -rEn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  "from\s*['\"].*${FILE%.*}['\"]" . > "$DIR/after.txt"

awk '/^(export\s+)?(async\s+)?(function|const\s+\w+\s*=\s*(async\s*)?\()/{print NR, $0}' "$FILE" >> "$DIR/after.txt"

wc -l "$DIR/before.txt" "$DIR/after.txt"
```

Verify:
- The god-file's LOC has dropped meaningfully (typically 30–70% per session).
- Fan-out from the god-file has dropped (it now imports the new hooks/services instead of containing them).
- Fan-in to the god-file is unchanged or slightly down (consumers haven't been rewired in this audit — only the internals moved).

If fan-out *increased*, something went wrong. Stop and re-read the file.

### 3.2 Run the file's test suite as a whole

Not just per-seam: the full integration of the now-refactored file with its new dependencies. Catches contract mismatches that per-seam tests miss.

### 3.3 Re-run STRUCTURAL_ENTROPY against this one file

Optional but recommended:

```
Run audits/STRUCTURAL_ENTROPY.md from $DETERMINAGENTS_HOME --target=<file>.
```

The file should drop out of the P0/P1 tier. If it doesn't, the seams were wrong — surface this to the user before declaring the session complete.

### 3.4 Final close-out commit

```
refactor(<file-slug>): structural refactor complete

Resolves STRUCTURAL_ENTROPY_<DATE>:<SEVERITY> #<FILE>
Before: <LOC>, <responsibilities>. After: <LOC>, <responsibilities>.
Seams: N. See docs/reports/refactor-artifacts/<report-name>/<file-slug>/.
```

---

## Severity rubric (resolver outcomes)

Same as `RESOLVE_FROM_REPORT.md` (Resolved / Already resolved / Invalid / Needs decision / Deferred / Failed), applied **per seam, not per file**. A file with 3 seams resolved and 1 deferred is partially complete and re-appears in the next session.

---

## Implementation rules (additions to RESOLVE_FROM_REPORT)

- **Contract before code, every time.** No exceptions for "obvious" seams. The half-failures are usually the obvious ones.
- **One seam per commit, two commits per seam.** Contract commit, then move commit. The split makes review and revert tractable.
- **Lowest-coupling seam first.** The order in the report is the order to execute. Reordering produces cascading conflicts.
- **The god-file can stop being a god-file mid-session.** If after seam 2 the file is no longer P1, the remaining seams may be P2 or P3 — surface that and ask whether to continue or close out.
- **Never extract into existing files without re-evaluating.** If the destination already exists, the contract becomes a merge problem and the seam is no longer a clean move. Treat as a new finding.
- **Do not rewrite the consumer sites in the same session.** The audit refactors the god-file's internals. Rewiring consumers to use the new modules directly (instead of going through the god-file) is a separate concern.

---

## Anti-patterns

- **Bundling contract + move into one commit.** Loses the ability to revert the move without losing the interface.
- **Reordering seams to "do the impressive one first."** High-coupling seams have hidden dependencies on lower-coupling extractions. The report's order exists for a reason.
- **Extracting into a file that already does something else.** That's just moving the god-file problem one level down.
- **"This seam is small, I'll skip the contract step."** The contract step is what separates this audit from copy-paste refactoring. Skip it and you've reinvented the failure mode.
- **Continuing when tests don't cover the moved code.** The whole point of this audit is to avoid the regression vector. Adding tests is a prerequisite, not a follow-up.

---

## Composition with other docs

- **Source**: `audits/STRUCTURAL_ENTROPY.md` report.
- **Prerequisite**: `audits/TESTING_CREATOR.md` Tier 1, if the god-file lacks coverage.
- **Re-audit**: re-run `STRUCTURAL_ENTROPY` after the session, scoped to the touched file, to confirm the file no longer scores P0/P1.
- **Follow-up**: if seams revealed cross-file architectural drift (e.g., three files all extracted the same hook), surface to the user — but resist consolidating in the same session. The audit refactors structure; consolidation is a separate decision.

The chain: **STRUCTURAL_ENTROPY → review seams → (TESTING_CREATOR Tier 1 if needed) → STRUCTURAL_REFACTOR → re-audit** is the full pattern.
