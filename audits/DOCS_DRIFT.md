# Documentation Drift Audit

## Purpose

Find claims in the project's documentation that the code no longer matches. README setup steps that fail on a fresh clone. Architecture diagrams describing services that were merged or deleted. API examples returning shapes the API hasn't returned in a year. Onboarding guides referencing tools the team replaced.

Drifted docs are worse than missing docs: they lie confidently to new contributors and outside users.

## When to run

Quarterly. Before publishing externally. After a major refactor or service merge/split. Read-only.


**Model tier**: `fast` — (Static comparison + regex/find work; flagship reasoning is wasteful here.)

## Time estimate

30–60 min.

## Output

`docs/reports/DOCS_DRIFT_<YYYY-MM-DD>.md`. Optionally accompany with PRs for the obvious fixes.

---

## Phase 0: Discovery

```bash
# Markdown files in repo, excluding deps and reports
find . -name '*.md' \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/vendor/*' -not -path '*/dist/*' \
  -not -path '*/reports/*' \
  | sort

# Doc directories
find . -type d \( -name 'docs' -o -name 'doc' -o -name 'documentation' \) \
  -not -path '*/node_modules/*' | head -10

# OpenAPI / schema docs
find . \( -name 'openapi*.yaml' -o -name 'openapi*.json' -o -name 'swagger*' \
  -o -name '*.proto' -o -name 'schema.graphql' \) -not -path '*/node_modules/*'
```

Record: top-level docs (README, CONTRIBUTING, ARCHITECTURE, etc.), doc directories, structured API docs.

---

## Phase 1: README Setup Path

The README's setup section is the most-read doc and the most-drifted. Walk through it as if you'd never seen the project.

For each step, classify:

- **Runs**: command exists, succeeds on a fresh clone
- **Stale**: command exists but does the wrong thing now (different output, different effect)
- **Broken**: command fails or references a missing tool/file/script
- **Aspirational**: described as if it works but doesn't yet

```bash
# Quick check: scripts referenced in README vs scripts that exist
grep -oE 'npm run [a-z:_-]+|make [a-z:_-]+|\./[a-zA-Z_./-]+\.(sh|py|js)|yarn [a-z:_-]+' README.md 2>/dev/null \
  | sort -u

# vs.
cat package.json 2>/dev/null | grep -A 50 '"scripts"' | head -60
ls Makefile 2>/dev/null && grep -E '^[a-z][a-z_-]*:' Makefile
```

Pay extra attention to: required env vars (does the README list all the ones the app actually reads from?), required services (Postgres versions, Redis presence, etc.), required tool versions (Node, Python, Go).

---

## Phase 2: Architecture Claims

Architecture docs (ARCHITECTURE.md, CLAUDE.md, START_HERE.md, design docs) often describe an idealized version of the system.

Cross-check each architectural claim:

- **Services listed**: do they all still exist? Any new services missing from the diagram?
- **Service responsibilities**: does the named service still do what the doc says?
- **Data stores**: still the same DB engine, version, schema strategy?
- **Auth model**: described auth flow matches code?

```bash
# Diff service lists: docs vs filesystem
grep -hoE '(services?|apps)/[a-z][a-z0-9_-]+' docs/*.md ARCHITECTURE.md README.md 2>/dev/null \
  | sort -u > /tmp/docs_services.txt

ls -d services/*/ apps/*/ 2>/dev/null | sed 's:/$::' | sort -u > /tmp/real_services.txt

echo "=== In docs, not in repo ==="
comm -23 /tmp/docs_services.txt /tmp/real_services.txt
echo "=== In repo, not in docs ==="
comm -13 /tmp/docs_services.txt /tmp/real_services.txt
```

---

## Phase 3: API Documentation Drift

If there's an OpenAPI/Swagger/GraphQL schema or hand-written API.md:

```bash
# Routes documented vs routes registered
# 1. Extract documented routes
grep -hoE '(GET|POST|PUT|DELETE|PATCH)\s+/[a-zA-Z0-9/_:{}.\-]+' docs/*.md API*.md 2>/dev/null \
  | sort -u > /tmp/docs_routes.txt

# 2. Extract registered routes (use the discovery commands from STUB_AND_COMPLETENESS.md Phase 1.2)
# ...into /tmp/real_routes.txt

# 3. Diff
comm -23 /tmp/docs_routes.txt /tmp/real_routes.txt    # documented but not implemented
comm -13 /tmp/docs_routes.txt /tmp/real_routes.txt    # implemented but not documented
```

Also: pick 3 documented endpoints. Check the documented request/response shape against the code (struct definition, response builder). Flag any field name, type, or required-ness mismatch.

---

## Phase 4: Code-Block Bitrot

Markdown docs with copy-pasteable code blocks rot fastest because nothing exercises them.

```bash
# Find fenced code blocks in docs
find . -name '*.md' -not -path '*/node_modules/*' -not -path '*/reports/*' \
  -exec grep -l '```' {} \;
```

For each significant code block (config snippets, command sequences, code examples), check:
- Does it still compile/parse?
- Do the imports/paths/flags still exist?
- Does the output match what the doc claims?

The bash blocks are the highest-yield: try running them in a scratch dir.

### Harness path: clean-container execution

Phase 4 above is described as static inspection ("does it still parse?"). The next-level investment is **executing each code block in a clean container** and reading the actual outcome. This is a pure harness pattern — disposable workspace (the container), execute (run the block), observe (exit code + stdout/stderr), classify (passed / failed / partial).

What this would look like:

```bash
# For each .md file with bash code blocks:
docker run --rm -v $(pwd):/repo:ro -w /repo \
  ubuntu:24.04 bash -c "
    apt-get update -qq && apt-get install -y curl git make
    # Extract and execute each fenced bash block in sequence
    # Record exit code, stdout, stderr per block
  "

# For each block:
#   exit 0          → block still works  → OK
#   exit non-zero   → block is broken    → P0 if in setup section, P2 otherwise
#   succeeds but    → block runs but outputs differ → P1 (silent drift)
#     output drifts
```

For setup instructions specifically (README "Getting Started" sections), the right harness is:

```bash
# Walk the README from a clean state
docker run --rm -v $(pwd):/repo:ro \
  <project base image> bash -c "
    # Follow steps from README Getting Started
    # Verify each step's success criterion
  "
```

When this audit is run with harness capability:
- Phase 4 → automated; every fenced bash block is exit-code-checked
- Phase 1 (README setup) → automated; the entire setup path runs in a clean container

This is not built into this audit yet. The minimal harness is doable in a few hours of project-specific scripting once the container baseline exists. See `specs/FORMAT.md` "Harness conventions" and `audits/SECURITY_HUNT.md` for the structural pattern.

---

## Phase 5: Cross-Reference Integrity

```bash
# Broken intra-repo links
find . -name '*.md' -not -path '*/node_modules/*' -not -path '*/reports/*' \
  -exec grep -Eo '\]\(([^)]+\.md|[^)]+\.[a-z]+)\)' {} \; \
  | sort -u
# Then for each, check the target exists. (Manual or scripted.)

# Broken anchors
grep -rEn '\]\(#[a-zA-Z0-9_-]+\)' --include='*.md' . | grep -v node_modules
```

---

## Phase 6: Stale Reports & Decisions

If the project has a `docs/reports/` or `docs/decisions/` (ADRs):

- Reports older than 6 months that describe a problem already fixed → archive
- ADRs marked "Proposed" that were obviously implemented → flip to "Accepted"
- ADRs marked "Accepted" that were silently reversed → flip to "Superseded"

```bash
# Reports by date
ls -lt docs/reports/ 2>/dev/null | head -20
ls -lt docs/decisions/ 2>/dev/null | head -20
```

---

## Phase 7: "Living Doc" Verification

Identify docs the team treats as authoritative (README, CONTRIBUTING, the onboarding doc, the runbook). For each:

- **Last meaningfully updated**: not just typo fixes
- **Verified against code today**: yes / no / partial
- **Owner**: is anyone responsible for this?

```bash
# Recent edits to top docs
git log --since='6 months ago' --pretty=format:'%h %ad %s' --date=short -- README.md docs/*.md 2>/dev/null | head -50
```

---

## Severity rubric

| Severity | Criteria |
|----------|----------|
| **P0** | Setup instructions fail on a fresh clone; broken auth doc misleads on a security-relevant flow |
| **P1** | Architecture diagram contradicts code on a load-bearing detail; documented API endpoint returns a different shape |
| **P2** | Stale references to deleted/renamed services or tools; broken intra-repo links |
| **P3** | Cosmetic — minor outdated screenshots, formatting drift, old version numbers |

---

## Report template

Reports must also include the universal sections from `specs/FORMAT.md` — `## Severity rubric (this audit)` (copied verbatim from this doc's rubric) and `## Next steps` (paste-ready RESOLVE_FROM_REPORT invocation with this report's path filled in). Audit-specific structure below:

```markdown
# Documentation Drift Audit — <DATE>

## Summary
- Docs reviewed: X
- Findings: X (P0: X, P1: X, P2: X, P3: X)

## P0 — Setup / safety-critical drift
| Doc | Claim | Reality | Suggested fix |
|---|---|---|---|

## P1 — Architecture / API drift
...

## P2 — Stale references
...

## P3 — Cosmetic
...

## Living docs status
| Doc | Last meaningful update | Status | Owner |
|---|---|---|---|
| README.md | 2026-02-14 | drift in setup section | @who |

## Archive candidates
List of files older than 6 months that describe resolved issues — recommend moving to `docs/reports/.archive/`.

## Recommendations
1. ...
```
