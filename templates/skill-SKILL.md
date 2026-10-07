---
name: determinagents
description: Universal audit harnesses for coding agents. Use when asked to audit, review, finish, or loop on codebase work — stubs, security, errors, tests, docs drift, UX, or autonomous completion.
---
<!-- generated-by: determinagents setup (templates/skill-SKILL.md). Safe to overwrite on re-setup. -->

# DeterminAgents

Portable audit harnesses. Library lives at `@LIBRARY_PATH@`
(or `$DETERMINAGENTS_HOME` when set — env wins).

## Run a behavior

The library CLI emits paste-ready prompts. Follow the emitted prompt;
don't paraphrase it from memory:

```sh
determinagents prompt --list               # all behaviors
determinagents prompt <behavior> [flags]   # e.g. complete, resolve, security
```

Execute the emitted prompt against the target repo.

## Conventions (every run inherits these)

- If the target repo has `docs/determinagents/AUDIT_CONTEXT.md`, read it
  first and apply its calibrations.
- Reports go to `docs/reports/` with `audit:`/`date:` frontmatter.
- Read-only by default. Mutating work needs a disposable workspace and
  per-action approval; never touch credentials or production.
- Loop cycles obey `specs/LOOP_PROTOCOL.md` §6 (gate ledger,
  anti-circularity, parallel-state budget, harness triage, credential
  safety).

## If the library is missing

```sh
curl -fsSL https://raw.githubusercontent.com/iansherr/determinagents/main/install.sh | sh
```
