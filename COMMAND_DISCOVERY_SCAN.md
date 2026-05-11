# DeterminAgents Command Discovery Scan
**Date**: 2026-05-11  
**Scope**: All local files defining `/determinagents` menu, invocation routing, and command naming conventions

---

## Executive Summary

The `/determinagents` command ecosystem is defined across **5 primary source files** plus supporting specs. The hub command (`/determinagents`) is the canonical entry point; individual behavior aliases (`/da-stub`, `/da-security`, etc.) are optional materialization variants. All routing logic is encoded in **INSTALL.md** (materialization templates) and **INVOCATIONS.md** (paste-ready prompts).

---

## Primary Source Files

### 1. **INSTALL.md** — Command Materialization Templates
**Path**: `/Users/iansherr/Projects/determinagents/INSTALL.md`  
**Purpose**: Agent-facing instructions for generating host-tool-specific command files  
**Key Sections**:
- **Lines 27–57**: Hub command template (`/determinagents`) for Gemini CLI (`.toml` format)
- **Lines 100–126**: Claude Code slash commands directory structure (legacy path)
- **Lines 145–150**: opencode native path (`.opencode/commands/`)
- **Lines 212–234**: Cursor Rules format (`.cursor/rules/*.mdc`)
- **Lines 236–246**: Generic/unknown host tool fallback

**Command Naming Conventions Defined**:
- Hub: `/determinagents` (primary, recommended)
- Individual audits: `audit-stub`, `audit-security`, `audit-data-flow`, `audit-error-handling`, `audit-test-gaps`, `audit-docs-drift`, `audit-ux-design`, `audit-p0-sweep`
- Mutating behaviors: `resolve-from-report`, `security-hunt`, `data-flow-verify`, `testing-creator`
- Bootstraps: `bootstrap-design`, `bootstrap-feature-registry`, `bootstrap-audit-context`, `refresh-audit-context`

**Critical Rule** (Lines 248–252): Materialized commands must be **thin pointers** (reference audit docs by path, not embed content) so library updates flow through automatically.

---

### 2. **INVOCATIONS.md** — Canonical Paste-Ready Prompts
**Path**: `/Users/iansherr/Projects/determinagents/INVOCATIONS.md`  
**Purpose**: Single source of truth for every behavior's invocation syntax and flags  
**Key Sections**:
- **Lines 9–24**: Shared conventions (library path, AUDIT_CONTEXT.md, reports location, severity levels)
- **Lines 61–102**: Audits table with `--flags` (phases, max-time, p0-only, target, +harness)
- **Lines 103–180**: Mutating behaviors (RESOLVE_FROM_REPORT, SECURITY_HUNT, DATA_FLOW_VERIFY, TESTING_CREATOR)
- **Lines 204–223**: Project Initialization (First Run) flow
- **Lines 226–283**: Per-project artifact bootstraps (DESIGN.md, FEATURE_REGISTRY.md, AUDIT_CONTEXT.md)
- **Lines 284–313**: Maintenance invocations (refresh, integrate, brainstorm modes)

**Flag Patterns**:
```
--phases=N,M          Run only listed phases
--max-time=Xm         Soft time budget
--p0-only             Stop after P0 findings
--target=<value>      Required for DATA_FLOW_TRACE, DATA_FLOW_VERIFY, SECURITY_HUNT
+harness              Enable mutating Phase 6 (STUB_AND_COMPLETENESS, ERROR_HANDLING only)
--tier=<N>            TESTING_CREATOR tiers (1–4)
--service=<name>      TESTING_CREATOR service scope
--from-report=<path>  Pull targets from existing report
--add=<feature-name>  Add single FEATURE_REGISTRY entry
--mode=<refresh|integrate|brainstorm>  Maintenance modes
--source=<url-or-path>  Maintenance integrate source
--seed=<topic>        Maintenance brainstorm seed
```

---

### 3. **UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md** — Proposed Alias Scheme
**Path**: `/Users/iansherr/Projects/determinagents/docs/maintenance/UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md`  
**Purpose**: UX improvement audit recommending hybrid interaction model  
**Proposed Aliases** (Lines 31–42):
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

**Recommendation**: Keep `/determinagents` as canonical hub; add `/da` router command with argument completion; add individual `/da-*` aliases for autocomplete-native discovery.

---

### 4. **bin/determinagents** — Shim Subcommand Routing
**Path**: `/Users/iansherr/Projects/determinagents/bin/determinagents`  
**Purpose**: POSIX shell shim for library installation and management  
**Key Subcommands** (Lines 33–86):
- `version|--version|-v` — Show installed version
- `path` — Print `$DETERMINAGENTS_HOME`
- `update` — Check for updates, show diff, apply with confirmation
- `materialize|install-commands` — Generate host-tool-specific command files
- `doctor` — Health check (install, shim, remote, shell completion)
- `completions <shell>` — Print tab-completion script (bash, zsh, fish)
- `uninstall` — Remove library with confirmation
- `help` — Full command list

**Critical Note** (Lines 5–9): Subcommand list lives in three places that must stay in sync:
1. `help` heredoc
2. `doctor`/`completions` outputs
3. Bash/zsh/fish completion bodies

---

### 5. **specs/BOOTSTRAP.md** — AUDIT_CONTEXT.md Generation
**Path**: `/Users/iansherr/Projects/determinagents/specs/BOOTSTRAP.md`  
**Purpose**: Spec for bootstrapping project-specific audit calibration overlay  
**Key Sections**:
- **Lines 1–26**: Purpose and scope (what belongs in AUDIT_CONTEXT.md)
- **Lines 28–33**: Two modes (cold bootstrap, warm overlay)
- **Lines 35–40**: Authoring rules (terse, link not inline)

**Invocation** (INVOCATIONS.md lines 262–283):
```
Bootstrap or update docs/determinagents/AUDIT_CONTEXT.md following
$DETERMINAGENTS_HOME/specs/BOOTSTRAP.md.

Optional flags:
  --from-report=<path>   Warm overlay: propose updates based on report
```

---

## Supporting Specification Files

### 6. **specs/FORMAT.md** — Self-Directed Agent Doc Format
**Path**: `/Users/iansherr/Projects/determinagents/specs/FORMAT.md`  
**Purpose**: Spec for audit document structure (applies to all audit docs)  
**Key Rules**:
- Required sections: Title, Purpose, When to run, Time estimate, Output, Discovery phase, Audit phases, Severity rubric, Report template
- Repo-specific OR self-discovering, never generic
- Read-only by default; label mutating phases `[MUTATING]`
- Phaseable (user can run Phase N only)
- Severity-scored (P0–P3 with written criteria)
- Concrete fixes (file:line + suggested fix)

---

### 7. **specs/FEATURE_REGISTRY.md** — Feature Registry Spec
**Path**: `/Users/iansherr/Projects/determinagents/specs/FEATURE_REGISTRY.md`  
**Purpose**: Spec for per-project feature catalog (output: `docs/determinagents/FEATURE_REGISTRY.md`)  
**Key Sections**:
- Header / how to use
- Design standards reference (link to DESIGN.md)
- Test infrastructure (URLs, accounts, viewports)
- Feature entries grouped by tag

---

### 8. **specs/AUDIT_CONTEXT_TEMPLATE.md** — Minimal AUDIT_CONTEXT Template
**Path**: `/Users/iansherr/Projects/determinagents/specs/AUDIT_CONTEXT_TEMPLATE.md`  
**Purpose**: Minimal skeleton for cold-bootstrap AUDIT_CONTEXT.md  
**Usage**: Referenced by BOOTSTRAP.md; agent copies sections from AUDIT_CONTEXT_SECTIONS.md as needed

---

### 9. **specs/AUDIT_CONTEXT_SECTIONS.md** — AUDIT_CONTEXT Section Catalog
**Path**: `/Users/iansherr/Projects/determinagents/specs/AUDIT_CONTEXT_SECTIONS.md`  
**Purpose**: Catalog of optional AUDIT_CONTEXT.md sections (agent selects which to include)  
**Sections**: Global, per-audit calibrations, known incidents, false positives, weak spots, severity overrides, conventions, archived paths

---

## Project-Specific Context Files

### 10. **docs/determinagents/AUDIT_CONTEXT.md** — Library's Own Context
**Path**: `/Users/iansherr/Projects/determinagents/docs/determinagents/AUDIT_CONTEXT.md`  
**Purpose**: Project-specific overlay for DeterminAgents library repo itself  
**Key Content**:
- Project type: Library of markdown + POSIX shell shim (no app code, API, DB, frontend, build)
- Executables: `bin/determinagents`, `install.sh` (POSIX sh, not bash)
- `docs/` distinction: `docs/determinagents/` and `docs/reports/` are paths in *target* projects, not this repo
- False positives to suppress: missing API endpoints, auth handlers, DB calls, frontend assets
- Applicable audits: DOCS_DRIFT, STUB_AND_COMPLETENESS
- Inapplicable audits: SECURITY_PENTEST, DATA_FLOW_TRACE, ERROR_HANDLING, UX_DESIGN_AUDIT, TEST_GAPS

---

## Routing & Discovery Logic

### Hub Command Flow (INSTALL.md lines 36–57)
1. User runs `/determinagents`
2. Hub displays menu verbatim (no shell commands until selection)
3. Hub checks for three files in project root:
   - `DESIGN.md`
   - `docs/determinagents/FEATURE_REGISTRY.md`
   - `docs/determinagents/AUDIT_CONTEXT.md`
4. Conditionally renders "First Run" section:
   - All three exist → omit section
   - Some exist → show "Re-init" option
   - None exist → show full "First Run" section
5. User selects behavior from menu

### Materialization Strategy (INSTALL.md lines 248–252)
- **Thin pointers**: Commands reference audit docs by path (`$DETERMINAGENTS_HOME/audits/<AUDIT>.md`)
- **Auto-update**: Library updates flow through without re-materialization
- **Re-materialize only when**: New behavior added, shared invocation header changes, hub command template changes

### Host-Tool Integration (INSTALL.md lines 100–246)
| Tool | Path | Format | Notes |
|------|------|--------|-------|
| Claude Code | `~/.claude/commands/` or `.claude/commands/` | Markdown + YAML frontmatter | Slash commands (legacy) or Skills (recommended) |
| opencode | `~/.opencode/commands/` or `.opencode/commands/` | Markdown + YAML frontmatter | Reads `~/.claude/skills/` as fallback |
| Gemini CLI | `~/.gemini/commands/` | TOML | Hub template provided (lines 33–57) |
| Cursor | `.cursor/rules/` | `.mdc` files with YAML frontmatter | Agent-requested mode (description only) |
| Other tools | Tool-specific | Tool-specific | Check tool docs; ask user if unclear |

---

## Command Naming Conventions

### Current (INSTALL.md lines 108–125)
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

### Proposed Aliases (UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md lines 31–42)
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

### Router Command (UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md lines 46–56)
```
/da <behavior> [flags]

Examples:
  /da ux --target=http://localhost:3000
  /da security --p0-only
```

---

## Shared Conventions (INVOCATIONS.md lines 9–24)

Every invocation inherits these:

1. **Library**: `${DETERMINAGENTS_HOME:-$HOME/.determinagents}/`
2. **Project context**: Read `docs/determinagents/AUDIT_CONTEXT.md` if present
3. **Reports**: Go to `docs/reports/<NAME>_<YYYY-MM-DD>.md`
4. **Findings**: Classified P0–P3 per audit's rubric
5. **Read-only by default**: Mutating docs require disposable workspace + approval
6. **Each finding**: Includes file:line + concrete suggested fix
7. **Discovery first**: Phase 0 of every audit identifies project shape

---

## Materialization Workflow (bin/determinagents materialize)

1. Agent detects host tool from context
2. Reads `INVOCATIONS.md` for all behaviors
3. Reads `INSTALL.md` for host-tool-specific template
4. Generates one file per behavior (thin pointer to audit doc)
5. If commands already exist:
   - Regenerates unchanged files silently
   - Prompts before overwriting hand-edited ones
   - Reports what changed
6. User confirms before writing

---

## Key Files for Patching

| File | Purpose | Patch Target |
|------|---------|--------------|
| `INSTALL.md` | Hub template + materialization instructions | Lines 27–57 (hub), 100–246 (host-tool templates) |
| `INVOCATIONS.md` | Paste-ready prompts + flag definitions | Lines 9–24 (conventions), 61–102 (audits table), 284–313 (maintenance) |
| `docs/maintenance/UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md` | Proposed alias scheme | Lines 31–42 (aliases), 46–56 (router command) |
| `bin/determinagents` | Shim subcommand routing | Lines 5–9 (sync note), 33–86 (subcommands) |
| `specs/BOOTSTRAP.md` | AUDIT_CONTEXT.md generation spec | Lines 1–40 (overview + modes) |
| `specs/FORMAT.md` | Audit doc format spec | Lines 1–40 (required sections + rules) |
| `specs/FEATURE_REGISTRY.md` | Feature registry spec | Lines 1–50 (structure + sections) |

---

## Verification Checklist

- [ ] Hub command (`/determinagents`) template in INSTALL.md matches intended UX
- [ ] Individual command naming (audit-*, bootstrap-*, etc.) consistent across INSTALL.md and INVOCATIONS.md
- [ ] Flag definitions in INVOCATIONS.md match audit doc Phase 0 discovery requirements
- [ ] Thin-pointer rule (INSTALL.md lines 248–252) enforced in all materialized commands
- [ ] Host-tool templates (Gemini, Claude, opencode, Cursor) up-to-date with tool conventions
- [ ] Proposed aliases (`/da-*`) and router command (`/da`) documented in UX audit
- [ ] Shared conventions (INVOCATIONS.md lines 9–24) applied consistently across all invocations
- [ ] Materialization workflow (bin/determinagents materialize) handles re-materialization case

---

## Notes for Downstream Patching

1. **INSTALL.md is the source of truth for materialization templates** — any changes to command structure, naming, or host-tool conventions must be reflected here first.

2. **INVOCATIONS.md is the source of truth for invocation syntax and flags** — audit docs reference this file; changes to flag patterns must be coordinated.

3. **Thin-pointer rule is non-negotiable** — materialized commands must reference audit docs by path, not embed content. This enables automatic updates when the library is updated.

4. **Subcommand list in bin/determinagents must stay in sync** with help heredoc, doctor output, and completion scripts (see lines 5–9).

5. **UX audit (UX_COMMAND_DISCOVERY_AUDIT_2026-05-11.md) proposes but does not implement** — it's a recommendation for hybrid interaction model (hub + aliases + router). Implementation requires changes to INSTALL.md templates and materialization logic.

6. **Host-tool conventions drift** — MAINTENANCE.md (specs/MAINTENANCE.md) includes a `--mode=refresh` audit to detect when host-tool conventions change. Run periodically to keep templates current.
