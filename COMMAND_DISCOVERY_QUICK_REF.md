# Quick Reference: Command Definition Files

## File Locations & Purposes

### Core Materialization
- **`INSTALL.md`** — Hub template + host-tool-specific command generation templates
  - Hub command: lines 27–57
  - Claude Code: lines 100–126
  - opencode: lines 145–150
  - Gemini CLI: lines 31–57
  - Cursor: lines 212–234
  - Thin-pointer rule: lines 248–252

- **`INVOCATIONS.md`** — Canonical paste-ready prompts for every behavior
  - Shared conventions: lines 9–24
  - Audits table: lines 61–102
  - Mutating behaviors: lines 103–180
  - Bootstraps: lines 226–283
  - Maintenance: lines 284–313

### Routing & Discovery
- **`bin/determinagents`** — Shim subcommand routing
  - Subcommand list sync note: lines 5–9
  - Subcommand cases: lines 33–86
  - Materialize subcommand: lines 88+

### UX Improvements
- **`docs/maintenance/UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md`** — Proposed alias scheme
  - Proposed aliases: lines 31–42
  - Router command: lines 46–56
  - Hybrid interaction model: lines 27–67

### Specifications
- **`specs/BOOTSTRAP.md`** — AUDIT_CONTEXT.md generation spec
- **`specs/FORMAT.md`** — Audit doc format spec
- **`specs/FEATURE_REGISTRY.md`** — Feature registry spec
- **`specs/AUDIT_CONTEXT_TEMPLATE.md`** — Minimal AUDIT_CONTEXT template
- **`specs/AUDIT_CONTEXT_SECTIONS.md`** — Optional AUDIT_CONTEXT sections catalog

### Project Context
- **`docs/determinagents/AUDIT_CONTEXT.md`** — Library's own audit context overlay

---

## Command Naming Patterns

### Current Naming (INSTALL.md lines 108–125)
```
audit-stub
audit-security
audit-data-flow
audit-error-handling
audit-test-gaps
audit-docs-drift
audit-ux-design
audit-p0-sweep
resolve-from-report
security-hunt
data-flow-verify
testing-creator
bootstrap-design
bootstrap-feature-registry
bootstrap-audit-context
refresh-audit-context
```

### Proposed Aliases (UX audit lines 31–42)
```
/da-stub
/da-security
/da-data-flow
/da-error-handling
/da-test-gaps
/da-docs-drift
/da-ux
/da-p0
```

### Router Command (UX audit lines 46–56)
```
/da <behavior> [flags]
```

---

## Flag Definitions (INVOCATIONS.md)

| Flag | Audits | Purpose |
|------|--------|---------|
| `--phases=N,M` | All audits | Run only listed phases |
| `--max-time=Xm` | All audits | Soft time budget |
| `--p0-only` | All audits | Stop after P0 findings |
| `--target=<value>` | DATA_FLOW_TRACE, DATA_FLOW_VERIFY, SECURITY_HUNT | Flow name or file path |
| `+harness` | STUB_AND_COMPLETENESS, ERROR_HANDLING | Enable mutating Phase 6 |
| `--tier=<N>` | TESTING_CREATOR | Tier 1–4 |
| `--service=<name>` | TESTING_CREATOR | Service scope |
| `--from-report=<path>` | SECURITY_HUNT, TESTING_CREATOR, AUDIT_CONTEXT | Pull targets from report |
| `--add=<feature-name>` | FEATURE_REGISTRY | Add single entry |
| `--mode=<refresh\|integrate\|brainstorm>` | Maintenance | Maintenance mode |
| `--source=<url-or-path>` | Maintenance integrate | Source to fold in |
| `--seed=<topic>` | Maintenance brainstorm | Brainstorm seed |

---

## Host-Tool Integration Matrix

| Tool | Path | Format | Notes |
|------|------|--------|-------|
| Claude Code | `~/.claude/commands/` or `.claude/commands/` | Markdown + YAML | Slash commands or Skills |
| opencode | `~/.opencode/commands/` or `.opencode/commands/` | Markdown + YAML | Reads `~/.claude/skills/` fallback |
| Gemini CLI | `~/.gemini/commands/` | TOML | Hub template provided |
| Cursor | `.cursor/rules/` | `.mdc` + YAML | Agent-requested mode |
| Other | Tool-specific | Tool-specific | Check tool docs |

---

## Materialization Workflow

1. User runs `determinagents materialize`
2. Agent detects host tool
3. Reads `INVOCATIONS.md` for all behaviors
4. Reads `INSTALL.md` for host-tool template
5. Generates one file per behavior (thin pointer to audit doc)
6. If commands exist: regenerate silently, prompt on hand-edits, report changes
7. User confirms before writing

**Critical**: Commands must reference audit docs by path, not embed content (thin-pointer rule).

---

## Shared Conventions (Every Invocation)

1. Library: `${DETERMINAGENTS_HOME:-$HOME/.determinagents}/`
2. Project context: Read `docs/determinagents/AUDIT_CONTEXT.md` if present
3. Reports: `docs/reports/<NAME>_<YYYY-MM-DD>.md`
4. Findings: P0–P3 per audit's rubric
5. Read-only by default; mutating phases require approval
6. Each finding: file:line + concrete fix
7. Discovery first: Phase 0 identifies project shape

---

## Sync Points (Must Stay in Sync)

- **bin/determinagents**: help heredoc, doctor output, completion scripts (lines 5–9)
- **INSTALL.md**: Hub template, host-tool templates, thin-pointer rule
- **INVOCATIONS.md**: Shared conventions, flag definitions, behavior list
- **Audit docs**: Phase 0 discovery, flag usage, report format

---

## For Patching

**Start here**: `INSTALL.md` (hub template + materialization logic)  
**Then**: `INVOCATIONS.md` (paste-ready prompts + flags)  
**Then**: `bin/determinagents` (if subcommand routing changes)  
**Then**: Audit docs (if Phase 0 or flag usage changes)  
**Verify**: UX audit recommendations (UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md)
