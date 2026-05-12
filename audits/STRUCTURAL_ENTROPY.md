# Structural Entropy Audit

## Purpose

Find god-files and god-modules before they calcify: files that accumulate unrelated responsibilities because adding a line is cheaper than picking a seam. This audit surfaces the structural pressure points, names the distinct responsibilities living in each one, and proposes concrete extraction seams (hooks, services, sub-components, libs). It does not refactor — that's `STRUCTURAL_REFACTOR.md`'s job.

The audit deliberately separates **what's true** (the file mixes five concerns and changes weekly) from **what to do** (extract the localStorage block into a hook). Mixing the two produces "make this cleaner" prompts that drift.

Read-only by default.

## When to run

- After a feature push that touched a small number of files heavily.
- When a new contributor onboards and asks "where does X live?" and the answer is "everywhere in this one file."
- Quarterly on any active codebase.
- Before planning a refactor sprint — this audit produces the input to that sprint.

**Model tier**: `default`

## Time estimate

30–90 minutes for a typical mid-size codebase. Scales with file count, not LOC. Use `--phases=N,M` or `--max-time=Xm` to scope.

## Output

`docs/reports/STRUCTURAL_ENTROPY_<YYYY-MM-DD>.md`.

Read `docs/determinagents/AUDIT_CONTEXT.md` first if it exists. Pay particular attention to the `STRUCTURAL_ENTROPY` section: exemption paths, per-area thresholds, and "what counts as one responsibility here" calibration. Without that overlay this audit will false-positive on legitimate large files (generated code, framework-shaped route handlers, switch-table modules).

---

## Phase 0: Discovery

Identify languages, the module boundary conventions, and what "big" means in this codebase.

```bash
# Languages and frameworks
ls package.json go.mod pyproject.toml Cargo.toml pom.xml Gemfile 2>/dev/null
find . -maxdepth 3 -name 'tsconfig*.json' -o -name 'next.config.*' -o -name 'vite.config.*' -o -name 'webpack.config.*' 2>/dev/null

# Size distribution — what does "big" look like here?
find . -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
  -o -name '*.go' -o -name '*.py' -o -name '*.rb' -o -name '*.java' -o -name '*.rs' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' \
  -not -path '*/vendor/*' -not -path '*/.next/*' \
  -exec wc -l {} + 2>/dev/null | sort -rn | head -40

# Generated / vendored / exempt patterns to subtract before scoring
grep -rEn --include='.gitattributes' --include='.gitignore' 'linguist-generated|generated' . 2>/dev/null | head -20
```

Record:
- Languages in scope
- Framework conventions that legitimately produce large files (e.g., Next.js route handlers, Rails controllers, big switch-on-enum files)
- LOC distribution: median, p90, p99 — the threshold for "outlier large" is project-relative
- Exempt paths from `AUDIT_CONTEXT.md STRUCTURAL_ENTROPY`

The threshold for further analysis in later phases is **p95 of LOC distribution**, not a fixed number. A 600-line file in a 200-LOC-median codebase is the same signal as a 3000-line file in a 1000-LOC-median codebase.

---

## Phase 1: Responsibility count

Goal: for each candidate file (above the p95 LOC threshold from Phase 0, minus exemptions), count distinct responsibilities. Line count alone is not the finding; **responsibility count is**.

A file has high responsibility count when it mixes signals from multiple of the categories below in one module:

| Category | Detection signal |
|---|---|
| UI rendering | JSX/template returns, DOM APIs, CSS-in-JS |
| State management | `useState`, `useReducer`, store wiring, context creation |
| Side effects / I/O | `fetch`, `axios`, SDK clients, `localStorage`, file I/O |
| Streaming / async coordination | SSE handlers, WebSocket, async generators, queue consumers |
| Data shaping | parsing, serialization, schema validation, normalization |
| Routing / dispatch | route maps, action dispatch, command tables |
| Persistence | DB queries, cache reads/writes, migrations |
| Domain logic | business rules without I/O |

```bash
# For each file flagged in Phase 0 as outlier-large, sample for category signals.
# Run per-file; the agent reads results and tallies categories present.
FILE="<path from phase 0>"
echo "=== $FILE ==="
grep -cE '(return\s*\(?\s*<|jsx|className=|<[A-Z][A-Za-z]*\s|<[a-z]+\s[^>]*>)' "$FILE"       # UI
grep -cE '(useState|useReducer|createContext|createStore|atom\(|signal\()' "$FILE"             # State
grep -cE '(fetch\(|axios\.|http\.|localStorage|sessionStorage|fs\.|readFile|writeFile)' "$FILE" # I/O
grep -cE '(EventSource|WebSocket|ReadableStream|async\s*\*|for await|emit\(|on\()' "$FILE"     # Streaming
grep -cE '(JSON\.parse|JSON\.stringify|schema|z\.|yup\.|joi\.|zod\.|parse\(|serialize)' "$FILE" # Shaping
grep -cE '(router\.|route\(|switch\s*\([^)]*action|dispatch\()' "$FILE"                        # Routing
grep -cE '(db\.|prisma\.|knex\.|sequelize\.|SELECT |INSERT |UPDATE |DELETE )' "$FILE"          # Persistence
```

Record per file:
- Categories present (count of non-zero rows)
- Top two categories by signal strength
- LOC
- Severity (see rubric — three or more categories = P1 floor)

A file mixing **UI + State + I/O + Streaming** is the canonical "agent-workspace.tsx" god-file. Three categories = warning, four+ = god-file confirmed.

---

## Phase 2: Fan-in / fan-out asymmetry

Goal: identify modules that are both broadly depended on **and** broadly dependent — these are structural pressure points regardless of LOC.

```bash
# Fan-in: how many files import this file?
# Replace EXT with the dominant extension(s); the agent runs this for each candidate.
FILE="src/components/agent-workspace"   # without extension
grep -rEn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  "from\s*['\"].*${FILE}['\"]" . | wc -l

# Fan-out: how many distinct modules does this file import?
grep -cE "^import\s|^from\s" "$FILE.tsx"
```

Flag examples:
- **Fan-in > 10 AND fan-out > 20**: this file is a central hub *and* a broad consumer. Changes here ripple far in both directions.
- **Fan-in = 1, fan-out > 30, LOC > p95**: classic god-leaf — one parent component owning everything.
- **Fan-in > 20, fan-out < 5**: shared utility, usually fine; only flag if responsibility count is also high.

Record per flagged file: fan-in count, fan-out count, top 5 importers, top 5 imported modules.

---

## Phase 3: Change-velocity hotspots

Goal: find the files that absorb the most churn. High-churn files mixed with high responsibility count are where bugs cluster.

```bash
# Files changed most in the last 6 months (adjust window per AUDIT_CONTEXT).
git log --since='6 months ago' --name-only --pretty=format: \
  | grep -vE '^$|node_modules|dist|build|\.lock$|package-lock' \
  | sort | uniq -c | sort -rn | head -30

# Authors per file — high author count + high churn = "everyone edits this, no one owns it"
git log --since='6 months ago' --pretty='%ae' -- "<file>" | sort -u | wc -l
```

Record per top-churn file:
- Commit count in window
- Distinct author count
- Overlap with Phase 1 (high responsibility count) and Phase 2 (high fan-in/out)

A file appearing in all three phases is the highest-priority finding. The triple overlap is the signal — any one alone is weaker.

---

## Phase 4: Mixed abstraction levels (intra-file)

Goal: detect god-functions inside otherwise-reasonable files, and detect "abstraction salad" — code that flips between high-level orchestration and low-level mechanics within the same scope.

```bash
# Largest functions / methods per candidate file.
# Heuristic: contiguous indented blocks. Agent reads top 5 by length.
awk '/^(export\s+)?(async\s+)?(function|const\s+\w+\s*=\s*(async\s*)?\(|class\s)/{name=$0; start=NR} \
     /^}/{if(name){print NR-start, name; name=""}}' "$FILE" | sort -rn | head -10
```

Then read the top 1–2 functions and look for:
- A single function that fetches **and** parses **and** renders **and** persists.
- localStorage / sessionStorage calls interleaved with render logic.
- Inline `fetch` next to JSX in the same function body.
- `try/catch` blocks that swallow errors from operations belonging to different concerns.

These are the seams. Each one is a candidate extraction point for the companion mutating audit.

Record:
- File:function-name:start-line for each god-function.
- The 2–4 distinct responsibilities mixed inside it.
- A one-line proposed seam (e.g., "extract localStorage block at lines 412–438 into `useWorkspacePersistence` hook").

---

## Phase 5: Synthesis — seams, not refactors

For each confirmed god-file (Phase 1 multi-category **and** present in at least one of Phase 2/3/4), produce a **seam proposal**, not a refactor plan.

A seam proposal names:
- **What to extract**: the responsibility (e.g., "all localStorage read/write paths").
- **Where it goes**: hook / service / sub-component / lib / domain module.
- **The contract**: the interface the extracted unit exposes back to the original file.
- **Order hint**: which extraction to do first based on lowest coupling (the easiest seam, not the most impactful).

Do not write the refactor here. Do not propose file contents. A seam proposal is one sentence per dimension above.

Example:
> **File**: `src/components/agent-workspace.tsx` (3,123 LOC, 5 responsibilities, fan-in 14, fan-out 38, 89 commits / 6 authors in 6 months)
> **Seam 1**: Extract localStorage persistence (lines 412–438, 501–522, 1104–1128) → `src/hooks/useWorkspacePersistence.ts` → `{ state, setState, isHydrated }` → **do first** (no other code in the file consumes the intermediate state; lowest coupling).
> **Seam 2**: Extract SSE stream handling (lines 1400–1812) → `src/lib/agentStream.ts` service → `{ start(opts), stop(), onMessage(cb) }` → do second.
> **Seam 3**: Extract toolbar JSX (lines 200–340) → `src/components/WorkspaceToolbar.tsx` → props derived from current `workspace` state shape → do last (consumes outputs of seams 1 and 2).

---

## Severity rubric (this audit)

- **P0**: Responsibility count ≥ 4 **AND** present in Phase 3 top 10 **AND** has caused a recent incident or recurring regression (named in AUDIT_CONTEXT.md or commit messages). Refactor blocking further feature work.
- **P1**: Responsibility count ≥ 4 **OR** (responsibility count ≥ 3 **AND** appears in Phase 2 or Phase 3 top 10). True god-file. Schedule extraction.
- **P2**: Responsibility count = 3 with no Phase 2/3 overlap, **OR** outlier LOC with low responsibility count but high churn. Watch; not yet urgent.
- **P3**: Outlier LOC only (single responsibility, low churn, low fan-in/out). Often legitimate — generated code, big switch tables, framework-shaped files. Document the exemption in AUDIT_CONTEXT and move on.

LOC alone never produces a severity above P3. The categorical signals do.

---

## Report template

```markdown
# Structural Entropy Audit — <YYYY-MM-DD>

## Severity rubric (this audit)
- **P0**: Responsibility count ≥ 4, top-10 churn, incident-linked.
- **P1**: Responsibility count ≥ 4, OR ≥ 3 with fan-in/out or churn overlap.
- **P2**: Responsibility count = 3, no overlap; OR outlier LOC + high churn only.
- **P3**: Outlier LOC alone (often legitimate; document exemption).

## Summary
- Files analyzed: X (above p95 LOC threshold of <N> lines)
- Findings: X (P0: X, P1: X, P2: X, P3: X)
- Phases run: 0, 1, 2, 3, 4, 5
- LOC distribution observed: median <N>, p90 <N>, p95 <N>, p99 <N>

## God-file inventory

| Severity | File | LOC | Responsibilities | Fan-in / Fan-out | Commits / Authors (6mo) |
|---|---|---|---|---|---|
| P1 | `src/components/agent-workspace.tsx` | 3,123 | UI, State, I/O, Streaming, Persistence | 14 / 38 | 89 / 6 |

## Seam proposals

### `src/components/agent-workspace.tsx` (P1)

Context: 3,123 LOC, 5 responsibilities, 89 commits across 6 authors in last 6 months. Triple-overlap (Phase 1 + 2 + 3).

| # | Extract | Lines | Destination | Contract | Order |
|---|---|---|---|---|---|
| 1 | localStorage persistence | 412–438, 501–522, 1104–1128 | `src/hooks/useWorkspacePersistence.ts` | `{ state, setState, isHydrated }` | **first** (lowest coupling) |
| 2 | SSE stream handling | 1400–1812 | `src/lib/agentStream.ts` | `{ start(opts), stop(), onMessage(cb) }` | second |
| 3 | Toolbar JSX | 200–340 | `src/components/WorkspaceToolbar.tsx` | props from `workspace` state | last (depends on 1, 2) |

(repeat per file)

## Patterns observed

2–4 paragraph synthesis. Examples of what to surface here:
- "Three of four god-files share a localStorage block that wants to be one hook."
- "All P1 files are leaf components — pattern is 'parent owns everything', not 'shared utility grows unbounded'."
- "High-churn god-files cluster in features added during Q1; lower-churn ones predate the refactor pass."

## Exempt files (intentional outliers)

Files above the LOC threshold but **not** god-files: generated code, framework-shaped handlers, switch tables. Note these here so future runs skip them and so the exemption rationale is preserved.

| File | LOC | Why exempt |
|---|---|---|

## Next steps

Suggested invocations to act on this report.

**Refactor the highest-priority god-file:**

```
Run audits/STRUCTURAL_REFACTOR.md from $DETERMINAGENTS_HOME against the
report at <THIS_REPORT_PATH>, scope=P0,P1.

Read docs/determinagents/AUDIT_CONTEXT.md first.

Work one file at a time, one seam at a time, one commit per extraction.
Show me the contract and order before touching code.
```

**Persist exemptions so future runs skip known-legitimate large files:**

Add an `### Exempt paths` block under `STRUCTURAL_ENTROPY` in
`docs/determinagents/AUDIT_CONTEXT.md` listing the files from the Exempt
section above.

**Re-run this audit after the refactor to verify entropy reduction:**

```
[same invocation that produced this report]
```

## Recommendations

Cross-cutting recommendations, separate from per-file seams. Examples:
- Establish a convention for where new persistence/streaming/etc. logic lives, so the next feature push doesn't recreate the god-file.
- Add a CI check or pre-commit hook that flags files crossing the p95 LOC line for review (not as a hard block — LOC alone isn't the signal, but it's a useful prompt).
- If multiple god-files share the same extracted hook/service, consider whether the shared abstraction belongs in a domain module before extracting it twice.
```
