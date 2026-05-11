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

**Template for Gemini CLI (`~/.gemini/commands/determinagents.toml`):**

```toml
description = "Library Hub — interactive list of all DeterminAgents audits and tools"
prompt = \"\"\"
You are the **DeterminAgents Library Hub**.

IMMEDIATE ACTION: Display the menu below to the user verbatim. Do NOT perform any shell commands, file searches, or research until the user has selected an item from the menu.

ONE EXCEPTION — adapt the "First Run" section based on which core
project artifacts already exist. Check for these three files in the
current project root:

  - DESIGN.md
  - docs/determinagents/FEATURE_REGISTRY.md
  - docs/determinagents/AUDIT_CONTEXT.md

Then render the First Run section conditionally:

  - If ALL THREE exist: omit the entire "🚀 First Run" section.
  - If SOME exist: replace the section with one line under "Bootstraps":
      "**Re-init**: bootstrap any missing core artifacts (lists which are missing)."
  - If NONE exist: render the section as written below.

This check is a quick filesystem stat — no shell commands or
listings should be shown to the user. Then display the menu.

---
**DeterminAgents Library** (Path: <ABSOLUTE_PATH_TO_LIBRARY>)
Read docs/determinagents/AUDIT_CONTEXT.md if present. Reports go to docs/reports/.

### 🚀 First Run (Recommended)
- **Initialize Project**: Survey codebase and bootstrap missing core artifacts (DESIGN, FEATURE_REGISTRY, AUDIT_CONTEXT) to calibrate future audits.

### Available Audits (Read-Only)
... [Menu Content from INVOCATIONS.md] ...

**Which behavior would you like to run?**
---
\"\"\"
```

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

Two conventions, both supported. Skills are the current recommended path; slash commands are the legacy path and remain fully functional.

**Skills** (recommended): `~/.claude/skills/<skill-name>/SKILL.md` (global) or `.claude/skills/<skill-name>/SKILL.md` (project-local). Each skill is a directory with a `SKILL.md` entry point. Follows the [AgentSkills.io](https://agentskills.io) open standard.

**Slash commands** (legacy, still fully supported): Markdown files in `~/.claude/commands/` (global) or `.claude/commands/` (project-local). The filename minus `.md` becomes the command name.

For most DeterminAgents invocations, **slash commands are still sufficient** — each invocation is a thin pointer to one audit doc. Promote to a skill only if you need to bundle supporting files alongside the command.

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
```

The user invokes with flags: `/testing-creator --tier=2 --service=billing`, `/resolve-from-report --scope=P0`, `/audit-stub +harness`, etc. One slash command per behavior, flags handle variation.

**Frontmatter fields (Claude Code slash commands):**

| Field | Notes |
|-------|-------|
| `description` | Required — shown in `/` menu |
| `model` | Concrete model name; user can override at any time |
| `argument-hint` | Short hint shown in autocomplete |
| `allowed-tools` | Pre-approve tools to reduce permission prompts per invocation |
| `effort` | Thinking budget for reasoning-tier models: `low / medium / high / xhigh / max` |
| `context: fork` | Run the command in a subagent rather than inline (useful for heavy audits) |

**opencode compatibility:** Commands installed at `~/.claude/commands/` (and `~/.claude/skills/`) are also picked up by [opencode](https://opencode.ai), which uses the same convention as a fallback. A single install serves both tools.

**Docs:** [code.claude.com/docs/en/slash-commands](https://code.claude.com/docs/en/slash-commands)

### Honoring `Model tier` hints

Each audit doc in `$DETERMINAGENTS_HOME/audits/` declares a model tier (`reasoning` / `default` / `fast`) near the top — see `specs/FORMAT.md` "Model tier hints." Materialization should encode this into the slash command in the cleanest way the host tool supports:

| Host tool | Mechanism |
|-----------|-----------|
| Claude Code | Add `model: <name>` to the slash command's frontmatter, mapping the tier to a concrete model. The user can override at any time. |
| Cursor | Body recommendation; agent surfaces when invoked |
| Gemini CLI / others | Body recommendation |

Concrete tier-to-model mapping is the materializing agent's job, using whatever the host tool currently exposes. The mapping is conceptually simple — for each vendor:

- `reasoning` → the largest / most capable reasoning model in the current lineup
- `default`   → the mid-tier workhorse general-purpose model
- `fast`      → the smallest / fastest / cheapest production model

Specific model names are intentionally not listed here — vendor lineups change every few months, and any list this file maintained would rot. The materializing agent should look up current names at materialization time. Re-run materialization periodically to refresh bindings as new models ship.

**Vendor notes (as of 2026-05):**
- *Anthropic (Claude)*: Reasoning-tier models support a thinking-budget dial via the `effort` frontmatter field (`low` → `max`). This is not a separate tier — it's a per-invocation cost/quality knob available on Opus and some Sonnet variants.
- *Google (Gemini)*: A Flash-Lite sub-tier (cheaper/faster than Flash) exists below the standard three tiers. Pro/Ultra models support a "Deep Think" mode (separately billed reasoning tokens), analogous to Claude's extended thinking.
- *OpenAI (GPT)*: The separate o-series "reasoning model" family has been consolidated into the GPT-5 line, where internal reasoning is always on. The fast/default split is now GPT-5.x mini vs. GPT-5.x — no distinct reasoning-tier model family.

**Naming convention**: `audit-*` for read-only audits, `resolve-*` and `*-hunt` and `*-verify` for mutating, `bootstrap-*` for cold-start generators, `refresh-*` for maintenance.

### Gemini CLI

Gemini CLI uses `~/.gemini/commands/` for global commands and `.gemini/commands/` for project-local. Commands must be in **TOML format** with a **`.toml`** extension.

**Subdirectory namespacing** is supported: a file at `.gemini/commands/group/name.toml` is invoked as `/group:name`. Use this to namespace DeterminAgents commands if desired (e.g., `.gemini/commands/da/audit-stub.toml` → `/da:audit-stub`).

**Prompt body interpolation** (within the `prompt` value):
- `{{args}}` — injects arguments the user passes at invocation time
- `!{command}` — executes a shell command and injects its output (user confirmation required)
- `@{path}` — injects file or directory content (multimodal support)

**File template (`~/.gemini/commands/audit-stub.toml`):**

```toml
description = "Run STUB_AND_COMPLETENESS audit"
prompt = """
Library at $DETERMINAGENTS_HOME. Read docs/determinagents/AUDIT_CONTEXT.md if present.

Read $DETERMINAGENTS_HOME/audits/STUB_AND_COMPLETENESS.md and run it
against this repo. Additional flags: {{args}}

Report to docs/reports/STUB_AUDIT_<YYYY-MM-DD>.md.
"""
```

**Docs:** [github.com/google-gemini/gemini-cli/blob/main/docs/cli/custom-commands.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/custom-commands.md)

### Cursor

Cursor uses **Rules** (`.cursor/rules/*.mdc` for project-local). Each `.mdc` file is a rule with YAML frontmatter.

**Note:** The legacy `.cursorrules` single-file format is deprecated and ignored in Agent mode. Do not generate it.

**Frontmatter fields:**

| Field | Notes |
|-------|-------|
| `description` | Shown to the agent when deciding whether to apply the rule |
| `globs` | File patterns for auto-attach (e.g., `src/**/*.ts`) |
| `alwaysApply` | If `true`, always load — use sparingly |

**Activation mode** is set by which fields are present:
- `alwaysApply: true` → loaded into every context
- `globs:` set → auto-attached when matching files are open
- Only `description:` → agent-requested (AI decides when to apply)
- No trigger fields → manual (user invokes via `@rule-name`)

For DeterminAgents invocations (run on demand), use **agent-requested** mode: set `description:` only and let the agent surface the rule when relevant.

**Docs:** [cursor.com/docs/rules](https://cursor.com/docs/rules)

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
   - `.claude/` exists or working in Claude Code? → Claude Code (also serves opencode)
   - `~/.gemini/` exists? → Gemini CLI
   - `.cursor/` exists? → Cursor
   - `.opencode/` exists but no `.claude/`? → opencode (use Claude Code convention — shared compatibility)
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

`determinagents uninstall` removes the library directory itself but **does not** touch host-tool slash commands generated by `materialize`. To remove those, hand the following prompt to an agent inside the same host tool that originally installed them:

```
Remove every DeterminAgents slash command from this host tool.

These are files generated by an earlier `materialize` step and live in
the host tool's prompt-as-file directory:

  - Claude Code: ~/.claude/commands/ or ~/.claude/skills/  (or .claude/ equivalents if installed per-project)
  - Gemini CLI:  ~/.gemini/commands/
  - Cursor:      .cursor/rules/  (project-local)
  - Other tools: see ${DETERMINAGENTS_HOME:-$HOME/.determinagents}/INSTALL.md

Identify files generated by this library by either:
  1. A frontmatter/header comment naming ${DETERMINAGENTS_HOME:-$HOME/.determinagents}/INSTALL.md
     as the source (preferred — robust to renames), OR
  2. A body that references $DETERMINAGENTS_HOME or
     "Read .../audits/<name>.md" (fallback for older installs).

Show the list of files you'd remove and wait for explicit approval
before deleting anything. Do NOT match by filename alone — user-authored
commands may share the audit-* / resolve-* naming convention.
```

**Materialization should leave a removable marker.** When generating slash commands, include a single comment line at the top such as `<!-- generated-by: ${DETERMINAGENTS_HOME}/INSTALL.md -->` (or the equivalent in the host tool's comment syntax). This makes the uninstall step deterministic and safe.

## Anti-patterns to avoid

- **Don't bake library content into the slash command body.** Reference the audit doc by path; let the agent re-read the latest version. Otherwise commands rot when audits update.
- **Don't install per-project unless the user asks.** Most users want this library globally available across repos.
- **Don't install host-tool-specific extensions** (e.g., custom JSON schemas, hidden settings). Stick to the documented prompt-as-file convention so users can inspect, edit, and version-control the result.
- **Don't generate more files than `INVOCATIONS.md` defines.** No "convenience aliases" or duplicates. One invocation, one file.
