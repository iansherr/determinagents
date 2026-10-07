---
description: Run a DeterminAgents audit harness against this repo
argument-hint: <behavior> [flags] — try `complete`, `resolve`, `security`
---
<!-- generated-by: determinagents setup (templates/claude-command.md). Safe to overwrite on re-setup. -->

Library at `@LIBRARY_PATH@` (or `$DETERMINAGENTS_HOME` when set — env wins).

Run `determinagents prompt --list` to see behaviors, then
`determinagents prompt <behavior> [flags]` (behavior and flags come from
the arguments to this command, or pick the most relevant one and say
which you picked) and follow the emitted prompt against this repo.

Conventions: read `docs/determinagents/AUDIT_CONTEXT.md` first if
present; reports to `docs/reports/`; read-only by default, mutating work
needs approval and a disposable workspace.
