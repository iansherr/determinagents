# Install

Instructions for an AI agent to materialize this library into the host tool's prompt-as-file convention (slash commands, skills, snippets, etc.).

The library itself is **portable markdown** — every audit can be invoked by pasting from `INVOCATIONS.md`. This file is for the optional layer where you want one-keystroke invocation in your daily tool.

## How to use this file

Point an agent at this file from inside a host tool and ask it to install the library:

```
Read /Users/iansherr/Projects/self-directed-agents/INSTALL.md and install the
self-directed-agents library for this host tool. Identify the host tool from
context (e.g., this is Claude Code if you have access to .claude/), pick the
appropriate target convention from the table below, and generate the
install files. Show the plan before writing any files.
```

The agent does the rest: detects the host tool, reads `INVOCATIONS.md`, and generates the host-tool-specific files.

## What gets installed

Every entry in `INVOCATIONS.md` becomes one host-tool artifact. The mapping:

| Source (in `INVOCATIONS.md`) | Generated artifact |
|------------------------------|-------------------|
| Each audit invocation (1.1–1.7) | One slash command / skill per audit |
| Each TESTING_CREATOR tier (2.1–2.4) | One slash command per tier |
| Each bootstrap / sync invocation (3.x) | One slash command per behavior |
| Maintenance invocations (4.x) | One slash command per behavior |

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
├── verify-tier-adversarial.md
├── verify-tier-chaos.md
├── verify-tier-simulation.md
├── verify-tier-forensics.md
├── bootstrap-design.md
├── bootstrap-feature-registry.md
├── bootstrap-audit-context.md
├── add-feature.md
├── audit-registry-sync.md
└── refresh-audit-context.md
```

**Skills** (richer, for behaviors with multi-file context): `~/.claude/skills/<skill-name>/SKILL.md` plus supporting files. Use this when an invocation needs to reference more than one file from the library at runtime.

For most invocations, slash commands are sufficient. Promote to a skill only when needed.

**Naming convention**: `audit-*` for read-only audits, `verify-tier-*` for TESTING_CREATOR tiers, `bootstrap-*` for cold-start generators, `add-*` for in-PR additions, `refresh-*` for maintenance.

### Gemini CLI

Gemini CLI uses `~/.gemini/commands/` with a similar markdown-file convention. Same naming as Claude Code.

If the convention differs at install time, check Gemini's current docs and adapt.

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

## File template

For each invocation in `INVOCATIONS.md`, generate a file like this (Claude Code slash command example):

```markdown
---
description: <one-line description from INVOCATIONS.md "When" field>
---

# <Behavior Name>

<Shared conventions block — copied verbatim from INVOCATIONS.md top section>

## Invocation

<Prompt body from INVOCATIONS.md, with <ANGLE_BRACKET> placeholders preserved>

## Notes

- Library: /Users/iansherr/Projects/self-directed-agents/
- Source invocation: INVOCATIONS.md section <N.N>
- Variants (if applicable): <list>
```

Adapt the frontmatter to whatever the host tool expects. The body — shared conventions + invocation — should be identical across host tools so the prompts behave consistently.

## Installation procedure

When asked to install, the agent should:

1. **Detect host tool** by inspecting environment:
   - `.claude/` exists or working in Claude Code? → Claude Code
   - `~/.gemini/` exists? → Gemini CLI
   - `.cursor/` exists? → Cursor
   - Otherwise: ask the user.

2. **Detect scope**: project-local (`.claude/commands/`) vs. global (`~/.claude/commands/`). Default to global for this library since it's not project-specific. Confirm with user.

3. **Read source**: open `<LIBRARY_PATH>/INVOCATIONS.md` and extract the shared conventions block plus every numbered invocation (1.x, 2.x, 3.x, 4.x).

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
frontmatter naming /Users/iansherr/Projects/self-directed-agents/INSTALL.md
as their source.
```

The agent should look for that marker rather than guessing by filename, so user-authored commands sharing a naming convention are not deleted.

## Anti-patterns to avoid

- **Don't bake library content into the slash command body.** Reference the audit doc by path; let the agent re-read the latest version. Otherwise commands rot when audits update.
- **Don't install per-project unless the user asks.** Most users want this library globally available across repos.
- **Don't install host-tool-specific extensions** (e.g., custom JSON schemas, hidden settings). Stick to the documented prompt-as-file convention so users can inspect, edit, and version-control the result.
- **Don't generate more files than `INVOCATIONS.md` defines.** No "convenience aliases" or duplicates. One invocation, one file.
