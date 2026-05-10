# Install

Instructions for an AI agent to materialize this library into the host tool's prompt-as-file convention (slash commands, skills, snippets, etc.).

The library itself is **portable markdown** — every audit can be invoked by pasting from `INVOCATIONS.md`. This file is for the optional layer where you want one-keystroke invocation in your daily tool.

## How to use this file

Point an agent at this file from inside a host tool and ask it to install the library:

```
Read ${DETERMINAGENTS_HOME:-$HOME/.determinagents}/INSTALL.md and install the
determinagents library for this host tool.

Identify the host tool from context, pick the appropriate target convention,
and generate the install files. Start by creating the primary
`/determinagents` hub command that lists all available audits. Then, ask
if I want the full suite of individual slash commands or just the hub.

Show the plan before writing files.
```

The agent does the rest: detects the host tool, reads `INVOCATIONS.md`, and generates the host-tool-specific files.

## What gets installed

### The Hub: `/determinagents` (Primary)

The **best practice** for discoverability and keeping your slash command list clean. This single command provides a structured menu of all behaviors in the library.

When invoked, the hub should:
1. List the available categories (Audits, Mutating Tools, Bootstraps).
2. Briefly describe what each does.
3. Provide the full prompt for the user's chosen behavior (or just start it if the tool supports interactive selection).

### Individual Commands (Optional)

For power users who want one-keystroke access to specific audits, the full suite remains available.

| Source (in `INVOCATIONS.md`) | Generated artifact |
|------------------------------|-------------------|
| The Library Hub | `/determinagents` |
| Each audit (one per row in the audits table) | `/audit-stub`, `/audit-security`, etc. |
| Cross-audit P0 sweep | `/audit-p0-sweep` |
| RESOLVE_FROM_REPORT | `/resolve-from-report` |
| SECURITY_HUNT | `/security-hunt` |
| DATA_FLOW_VERIFY | `/data-flow-verify` |
| TESTING_CREATOR | `/testing-creator` |
| Per-project bootstraps (DESIGN, FEATURE_REGISTRY, AUDIT_CONTEXT) | `/bootstrap-design`, etc. |
| Maintenance | `/refresh-audit-context` |

The shared conventions block at the top of `INVOCATIONS.md` should become a **header included in every generated artifact**, so each command is self-contained.

## Host-tool targets

### Claude Code

Two conventions, both supported:

**Slash commands** (simpler, recommended default): Markdown files in `.claude/commands/` (project-local) or `~/.claude/commands/` (global). The filename becomes the command name.

```
~/.claude/commands/
├── audit-stub.md
├── audit-security.md
├── audit-data-flow.md
├── audit-error-handling.md
├── audit-test-gaps.md
├── audit-docs-drift.md
├── audit-ux-design.md
├── audit-p0-sweep.md
├── resolve-from-report.md
├── security-hunt.md
├── data-flow-verify.md
├── testing-creator.md
├── bootstrap-design.md
├── bootstrap-feature-registry.md
├── bootstrap-audit-context.md
└── refresh-audit-context.md
├── audit-security.md
├── audit-data-flow.md
├── audit-error-handling.md
├── audit-test-gaps.md
├── audit-docs-drift.md
├── audit-ux-design.md
├── audit-p0-sweep.md
├── resolve-from-report.md
├── security-hunt.md
├── data-flow-verify.md
├── testing-creator.md
├── bootstrap-design.md
├── bootstrap-feature-registry.md
├── bootstrap-audit-context.md
└── refresh-audit-context.md
```

The user invokes with flags: `/testing-creator --tier=2 --service=billing`, `/resolve-from-report --scope=P0`, `/audit-stub +harness`, etc. One slash command per behavior, flags handle variation.

### Honoring `Model tier` hints

Each audit doc in `$DETERMINAGENTS_HOME/audits/` declares a model tier (`reasoning` / `default` / `fast`) near the top — see `specs/FORMAT.md` "Model tier hints." Materialization should encode this into the slash command in the cleanest way the host tool supports:

| Host tool | Mechanism |
|-----------|-----------|
| Claude Code (recent versions) | Add `model: <name>` to the slash command's frontmatter, mapping the tier to a concrete model. The user can override at any time. |
| Older Claude Code / no frontmatter `model:` field | Add a body line: *"This audit prefers `reasoning`-tier models — use `/model opus` if you're not already on it."* The agent surfaces it. |
| Cursor | Body recommendation; agent surfaces when invoked |
| Gemini CLI / others | Body recommendation |

Concrete tier-to-model mapping is the materializing agent's job, using whatever the host tool currently exposes. The mapping is conceptually simple — for each vendor:

- `reasoning` → the largest / most capable reasoning model in the current lineup
- `default`   → the mid-tier workhorse general-purpose model
- `fast`      → the smallest / fastest / cheapest production model

Specific model names are intentionally not listed here — vendor lineups change every few months, and any list this file maintained would rot. The materializing agent should look up current names at materialization time. Re-run materialization periodically to refresh bindings as new models ship.

**Skills** (richer, for behaviors with multi-file context): `~/.claude/skills/<skill-name>/SKILL.md` plus supporting files. Use this when an invocation needs to reference more than one file from the library at runtime.

For most invocations, slash commands are sufficient. Promote to a skill only when needed.

**Naming convention**: `audit-*` for read-only audits, `resolve-*` and `*-hunt` and `*-verify` for mutating, `bootstrap-*` for cold-start generators, `refresh-*` for maintenance.

### Gemini CLI

Gemini CLI uses `~/.gemini/commands/` for global commands. Unlike other tools, it requires commands to be in **TOML format** with a **`.toml`** extension.

**File template (`~/.gemini/commands/audit-stub.toml`):**

```toml
description = "Run STUB_AND_COMPLETENESS audit"
prompt = \"\"\"
Library at \$DETERMINAGENTS_HOME. Read docs/determinagents/AUDIT_CONTEXT.md if present.

Read \$DETERMINAGENTS_HOME/audits/STUB_AND_COMPLETENESS.md and run it...
\"\"\"
```

### Cursor

Cursor uses **Rules** (`.cursor/rules/*.mdc` for project-local, settings for global). Each invocation can become a Rule with a trigger condition or a Command that's invoked manually.

For invocations that should run on demand (which is most of them), prefer the **Commands** path if available, otherwise create Rules with manual triggers.

### Other tools (Cline, Aider, Continue, etc.)

These typically use either `.<tool>/commands/` or a settings file with named prompts. The agent should:

1. Check the tool's documentation for the prompt-as-file convention.
2. If unclear, ask the user for the convention or installation path.
3. Generate one file per invocation following that convention.

### Generic / unknown host tool

If no convention is detectable, install nothing. Tell the user the library is portable as-is — they can paste from `INVOCATIONS.md` directly.

## Materialized files are thin pointers (read this twice)

This is the most important rule in this document. **The slash commands you generate must reference the audit docs by path, not embed their content.**

Why: when the library updates (`determinagents update`), the audit docs in `$DETERMINAGENTS_HOME/audits/` change. A thin-pointer command picks up the new content automatically the next time it runs. An inlined command would be frozen at materialization time and require re-running `materialize` after every library update — defeating the point of having a centrally-maintained library.

### Wrong (do not do this)

```markdown
---
description: Run STUB_AND_COMPLETENESS audit
---

# Phase 1: Frontend → Backend Contract Verification

### 1.1 Extract All Frontend API Calls
Scan every JavaScript file...
[500 lines of audit content inlined]
```

This will rot the moment the audit doc improves.

### Right

```markdown
---
description: Run STUB_AND_COMPLETENESS audit against this repo
---

Read $DETERMINAGENTS_HOME/audits/STUB_AND_COMPLETENESS.md and run it
against this repo, scope=${1:-standard} (quick | standard | deep).

If docs/determinagents/AUDIT_CONTEXT.md exists, read it first and apply
its calibrations.

Report to docs/reports/STUB_AUDIT_<YYYY-MM-DD>.md per the doc's report
template. Include file:line and a concrete suggested fix for every
finding. Do not commit the report until I review.
```

The slash command is ~10 lines. The audit doc is the source of truth. Updates flow through.

## File template

For each invocation in `INVOCATIONS.md`, generate a file like this (Gemini CLI example):

```toml
description = "<one-line description>"
prompt = \"\"\"
Library at <ABSOLUTE_PATH_TO_LIBRARY> (or \$DETERMINAGENTS_HOME if set).
Read docs/determinagents/AUDIT_CONTEXT.md if present.

<Prompt body from INVOCATIONS.md>
\"\"\"
```

**Note on paths**: While `INVOCATIONS.md` uses `$DETERMINAGENTS_HOME` for portability, the materializing agent should include the **absolute path** discovered during installation as a fallback. This ensures the command works immediately even if the user hasn't configured their environment variables yet.

### Re-materialization

Re-running materialize is only required when:

1. A new invocation is added to `INVOCATIONS.md` (new behavior).
2. The shared conventions header changes.
3. The host tool's frontmatter convention changes.

Day-to-day audit improvements (Phase changes, new commands, severity rubric updates) flow through automatically because the slash command always reads the live audit doc.

## Installation procedure

When asked to install, the agent should:

1. **Detect host tool** by inspecting environment:
   - `.claude/` exists or working in Claude Code? → Claude Code
   - `~/.gemini/` exists? → Gemini CLI
   - `.cursor/` exists? → Cursor
   - Otherwise: ask the user.

2. **Detect scope**: project-local (`.claude/commands/`) vs. global (`~/.claude/commands/`). Default to global for this library since it's not project-specific. Confirm with user.

3. **Read source**: open `$DETERMINAGENTS_HOME/INVOCATIONS.md` and extract the shared conventions block plus every behavior (audits, mutating docs, bootstraps, maintenance). Each becomes one slash command; flags pass through.

4. **Generate plan**: present the user with a list of files that will be created, e.g.:
   ```
   Will create at ~/.claude/commands/:
     audit-stub.md           (from §1.1 STUB_AND_COMPLETENESS)
     audit-security.md       (from §1.2 SECURITY_PENTEST)
     ... (16 more)
   Total: 18 files
   ```

5. **Get explicit approval** before creating any files.

6. **Generate files**: one per invocation, following the template above. Include the shared conventions header in each so commands are self-contained.

7. **Verify**: list the created files, run a smoke test (`/audit-p0-sweep --help` or equivalent if the host tool supports help text) if possible.

## Updating installed commands

When the library updates (`INVOCATIONS.md` changes), re-running the install procedure regenerates files. Existing files should be **overwritten** unless the user has hand-edited them — in which case prompt before overwriting.

A simple way to handle this: each generated file includes a comment with the source invocation's content hash. On re-install, files whose hash matches the current source can be overwritten silently; files whose hash doesn't match prompt the user.

## Uninstall

```
Remove every file in <INSTALL_PATH> that was generated from this library.
The marker is: files generated by this library have a comment in their
frontmatter naming ${DETERMINAGENTS_HOME:-$HOME/.determinagents}/INSTALL.md
as their source.
```

The agent should look for that marker rather than guessing by filename, so user-authored commands sharing a naming convention are not deleted.

## Anti-patterns to avoid

- **Don't bake library content into the slash command body.** Reference the audit doc by path; let the agent re-read the latest version. Otherwise commands rot when audits update.
- **Don't install per-project unless the user asks.** Most users want this library globally available across repos.
- **Don't install host-tool-specific extensions** (e.g., custom JSON schemas, hidden settings). Stick to the documented prompt-as-file convention so users can inspect, edit, and version-control the result.
- **Don't generate more files than `INVOCATIONS.md` defines.** No "convenience aliases" or duplicates. One invocation, one file.
