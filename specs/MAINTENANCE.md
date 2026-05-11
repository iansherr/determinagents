# Library Maintenance

## Purpose

Keep DeterminAgents honest and alive over time.

Host tools change their command conventions, model lineups shift every few months, and useful ideas surface in other repos and writeups. This is the maintainer's tool for noticing those things, integrating them, and exploring where the library should grow.

This is **not** a user-facing audit. End users running DeterminAgents on their own projects never invoke this. It lives in `specs/` rather than `audits/` for that reason.

**Model tier**: `reasoning` — the work involves cross-referencing documentation, judging applicability, and proposing edits.

## Output

Reports go to `docs/maintenance/<MODE>_<YYYY-MM-DD>[_<slug>].md`. The directory is gitignored — these are working notes for the maintainer, not library content.

## Modes

This doc supports three modes via `--mode=<refresh|integrate|brainstorm>`. Pick one per invocation.

---

## Mode: `refresh` (default)

**What it does**: audits the current library against the world as it exists today. Identifies drift between what `INSTALL.md`, `INVOCATIONS.md`, and the per-audit `Model tier` lines claim, vs. what host tools and model vendors actually offer.

### Phase 1: Host-tool convention drift

For each host tool documented in `INSTALL.md` (Claude Code, Gemini CLI, Cursor, OpenCode, plus the "other tools" mentioned), visit the tool's official docs and verify:

- The slash-command / skill / rule directory path still matches.
- The required and optional frontmatter fields match (and no new ones have appeared that we should be using — e.g., a `model` field, an `agent` field, a `subtask` flag).
- The file format hasn't changed (markdown ↔ TOML ↔ JSON).
- Any new dispatch rules have appeared (e.g., "Enter on a picker selection" vs. "Enter in input field" — the kind of asymmetry that bit us with OpenCode in May 2026).

For each drift found, propose the exact edit to `INSTALL.md`.

### Phase 2: New host tools

Search for coding-agent CLIs that have emerged or grown enough usage to warrant inclusion (e.g., past examples: OpenCode, Cline, Aider, Continue). For each candidate not in `INSTALL.md`:

- Note the tool's command convention (path, format, frontmatter).
- Decide: add as a documented target, or leave to the "other tools" generic guidance? Heuristic: if the convention is materially different from what's already documented, add it.
- Draft the new section.

### Phase 3: Model tier mapping freshness

`INSTALL.md` says vendor model names rot and the materializing agent should look them up at materialization time — but check the descriptive language is still accurate:

- Do the vendor names still have a clear "reasoning / default / fast" structure?
- Have any vendors collapsed tiers, renamed them, or introduced new categories (e.g., "thinking" budgets, mixture-of-experts) that need mention?

### Phase 4: Audit content staleness (light pass only)

Spot-check, do not full-audit. Look for:

- Dead URLs in audit docs (Mozilla writeup link, Google design.md links).
- Tools or libraries referenced in harness paths that have been deprecated or replaced (e.g., Playwright APIs, sanitizer flags).
- Audit phases that mention specific commands (`grep -rln`, etc.) that have changed defaults on common platforms.

### Report structure (`refresh`)

```markdown
# Library Refresh — <YYYY-MM-DD>

## Summary
<2-3 sentence overview of what's drifted>

## Phase 1: Host-tool drift
### <tool name>
- **Drift**: <what changed>
- **Source**: <URL>
- **Proposed edit**: <exact change to INSTALL.md, with file:line if locatable>

## Phase 2: New host tools
### <tool name>
- **Why it qualifies**: <usage signal, materially different convention, etc.>
- **Convention**: <path / format / frontmatter summary>
- **Draft section**: <ready-to-paste block for INSTALL.md>

## Phase 3: Model tier language
- **Findings**: <ok | drifted: ...>
- **Proposed edits**: <if any>

## Phase 4: Spot checks
- <one bullet per finding>

## Next steps
- <prioritized list — apply now / defer / discuss>
```

---

## Mode: `integrate`

**What it does**: takes a specific external source (a URL, a commit, a repo, a blog post, a tweet, or written description) and identifies what — if anything — should be folded into DeterminAgents.

Required: `--source=<url-or-path-or-description>`. Optional: `--note=<short paraphrase of why you flagged this>`.

### Procedure

1. **Read the source carefully.** Quote the specific passages, principles, or patterns that caught attention.
2. **Map to DeterminAgents.** For each candidate idea:
   - Where would it live? (existing audit, new audit, FORMAT.md convention, INSTALL.md guidance, README framing, etc.)
   - What problem in the current library does it address? If none, say so — not every interesting idea belongs here.
   - Honest assessment: is this *additive* (genuinely improves something), *redundant* (duplicates what we already encode structurally), or *misaligned* (would push the library in a direction that conflicts with the "simple prompt + good harness" principle)?
3. **Propose concrete edits**, not vibes. Diff-style if possible.
4. **Flag the friction**: if integrating this would require breaking changes, name them.

### Report structure (`integrate`)

```markdown
# Integrate: <source slug> — <YYYY-MM-DD>

## Source
<URL/path/description, plus the maintainer's --note if provided>

## Key passages
> <quote 1>
> <quote 2>

## Mapping to DeterminAgents

### Idea 1: <name>
- **Verdict**: additive | redundant | misaligned
- **Where it lives**: <file>
- **Proposed edit**: <diff or prose>
- **Why this and not the alternative**: <one sentence>

### Idea 2: ...

## What we're NOT taking
- <each rejected idea + one-sentence reason. Saying no is a feature.>

## Next steps
- <commit-ready edits / discussion items / defer>
```

---

## Mode: `brainstorm`

**What it does**: structured exploration of where the library should grow. Open-ended but bounded by the current shape — proposals must be consistent with the established principles (read-only by default, file:line + concrete fix in every finding, thin-pointer materialization, "simple prompt + good harness," etc.).

Optional: `--seed=<topic>` to focus the exploration (e.g., `--seed="performance audits"` or `--seed="harness patterns for mobile apps"`).

### Procedure

1. **Inventory the current library.** What audits exist? What harness patterns? What's covered by mutating docs vs. read-only? Where do users currently have to roll their own?
2. **Identify gaps** along these axes:
   - **Coverage gaps**: classes of bug or quality issue not addressed by any current audit.
   - **Harness gaps**: audits that surface findings but can't *verify* them — candidates for a SECURITY_HUNT-style execution-capable sibling.
   - **Workflow gaps**: friction points users hit between audits (e.g., the audit→resolve→re-audit loop was a workflow gap before RESOLVE_FROM_REPORT existed).
   - **Discoverability gaps**: things the library does well but no one finds.
3. **Propose 3–7 candidates.** For each:
   - **Working name** (uppercase if audit, e.g., `ACCESSIBILITY_AUDIT.md`).
   - **One-paragraph purpose** in the same voice as the existing audit purposes.
   - **Differentiator**: how is this distinct from existing audits?
   - **Risk of bloat**: is this big enough to deserve its own doc, or should it be a phase inside an existing one?
4. **Pick a top recommendation** with a one-paragraph case for prioritizing it now.

### Report structure (`brainstorm`)

```markdown
# Brainstorm — <YYYY-MM-DD>[, seed: <topic>]

## Current shape (as of this run)
- <quick inventory pulled fresh>

## Gaps surfaced
- **Coverage**: ...
- **Harness**: ...
- **Workflow**: ...
- **Discoverability**: ...

## Candidates

### 1. <NAME>
- **Purpose**: <one paragraph>
- **Differentiator**: <vs. existing X>
- **Risk of bloat**: <new doc | phase in existing | scrap>
- **Sketch of structure**: <phases / harness / output format>

### 2. ...

## Recommendation
<one paragraph: which candidate, why now, and what would tell us we were wrong>

## Honest non-recommendations
- <ideas that came up and got dropped, with one-sentence reason — "saying no is a feature">
```

---

## Invocation

This doc is invoked via the entry in `INVOCATIONS.md` §6 (Maintenance). The standard invocation:

```
Read $DETERMINAGENTS_HOME/specs/MAINTENANCE.md and run it in
--mode=<refresh|integrate|brainstorm>. For integrate, also
--source=<url-or-path>. For brainstorm, optionally --seed=<topic>.

Report to docs/maintenance/<MODE>_<YYYY-MM-DD>[_<slug>].md.
Do not commit the report (the directory is gitignored).
```

## Optional automation: maintenance signal report (maintainer-only)

Use this only if you want a recurring, low-noise input into `--mode=integrate` or `--mode=brainstorm`. This does **not** replace normal maintenance runs and does **not** mutate library files.

### Purpose

Generate a periodic, read-only snapshot of operational and ecosystem signals that may justify library updates.

### Output

`docs/maintenance/AUTO_SIGNAL_<YYYY-MM-DD>.md` (gitignored, same privacy model as other maintenance reports).

### Allowed data sources (read-only)

- Existing audit outputs under a target project's `docs/reports/` (especially capacity and reliability-oriented reports)
- Command outputs from read-only checks/runbooks (for example: resource pressure, restart counts, HTTP error rates, latency summaries)
- Tool/vendor release notes and changelogs relevant to DeterminAgents conventions

### Recommended signal groups

- **Capacity pressure**: sustained CPU/memory pressure, storage headroom decline, pod/container restarts
- **Reliability pressure**: elevated 5xx rates, timeout/connect-failure bursts, p95/p99 latency regressions
- **Dependency pressure**: DB/cache/queue saturation or timeout trends
- **Convention drift pressure**: host tool format/frontmatter/dispatch changes

### Safeguards (non-negotiable)

1. **Read-only collection only**. No mutating checks, no load generation.
2. **No auto-commit / no auto-PR by default**. The report proposes; maintainer decides.
3. **Redact secrets and sensitive identifiers** before writing the report.
4. **Bounded retention** for generated artifacts (keep recent windows, prune old runs).
5. **Escalation thresholds, not raw dumps**: summarize only when thresholds are crossed.
6. **Human approval gate** before any library edit derived from automation.

### Trigger thresholds (starter defaults)

Tune to your environment, but start with concrete triggers to avoid report spam:

- Error-rate trigger: sustained 5xx above 1% for 15m+
- Latency trigger: p95 increase above 30% vs. recent baseline window
- Resource trigger: sustained CPU or memory above 70% during normal workload windows
- Stability trigger: repeated restart loops or recurrent timeout/connect-failure patterns
- Drift trigger: any documented host-tool convention mismatch vs. `INSTALL.md`/`INVOCATIONS.md`

### How to use in this spec

1. Generate `AUTO_SIGNAL` report on a fixed cadence (for example weekly).
2. If no thresholds are crossed and no drift appears, record a short "no-action" summary.
3. If triggers fire, run `--mode=integrate --source=<AUTO_SIGNAL report path>` and decide what to adopt.
4. Proposed edits still follow this doc's normal rules (explicit diffs, honest non-recommendations, no direct mutation).

## Conventions

- **No mutating actions on the library itself.** This audit only *proposes* edits to `INSTALL.md`, `INVOCATIONS.md`, audit docs, README, etc. The maintainer reviews and applies them by hand (or via RESOLVE_FROM_REPORT pointed at the maintenance report).
- **One mode per run.** Modes have different output shapes; mixing them muddles the report.
- **Honest non-recommendations.** Every report ends with an explicit list of things considered and rejected. Saying no is the main signal that the audit is doing real work.
- **Cite sources.** Drift findings include the URL where the new convention is documented. Integrate findings quote the source verbatim. Brainstorm candidates name the analogous prior art if any.
- **Reports are private.** `docs/maintenance/` is gitignored. Don't paraphrase reports into commit messages without redacting any in-progress thinking.
