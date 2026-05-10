# Feature Registry Spec

A spec for `docs/determinagents/FEATURE_REGISTRY.md` — a per-project living catalog of every testable feature, structured so an agent can pick up **one** entry and execute it with no cross-referencing.

This file is the **spec**, like `google-labs-code/design.md` is the spec for `DESIGN.md`. Each project produces its own `FEATURE_REGISTRY.md` instance; this directory does not contain one.

## Why a registry

Three problems it solves:

1. **Bounded test invocations.** "Test the login flow" is ambiguous. "Test feature F03" is a hash key into a structured entry that contains URL, credentials, steps, pass criteria, and visual expectations.
2. **Surface tracking.** A registry diffed against the code reveals features that exist in code but aren't tested, and tests that reference features no longer in code.
3. **Composability.** Tags let you fan out: "test all `[admin]` features," "screenshot all `[public]` pages at 390/768/1280," "run visual checks on all features that use a payment flow."

## When to create

- After a project has stabilized enough that "the feature list" is meaningful (~10+ user-visible features).
- When manual QA is becoming the bottleneck and you want repeatable test invocations.

## When to update

- **Per-feature-shipped**: when a new page/screen/endpoint with user-visible behavior ships, add an entry in the same PR.
- **On removal**: when a feature is deleted, delete its entry in the same PR.
- **Quarterly drift audit**: see "Sync audit" below.

## Output location

`docs/determinagents/FEATURE_REGISTRY.md` (in the target project).

---

## File structure

```
1. Header / how to use
2. Design standards reference  (link to DESIGN.md if present)
3. Test infrastructure         (URLs, accounts, viewports, tools, screenshot path)
4. Feature entries, grouped by tag
```

### 1. Header

One paragraph: what this file is, how to invoke an entry, the rule that this file IS the test suite definition.

### 2. Design standards reference

Required if the project has a `DESIGN.md`. A short table linking common visual checks (colors, typography, spacing, radii, shadows, motion, touch targets, focus, dark mode, responsive) to their DESIGN.md sections. Tells the agent: "any visual test must be evaluated against DESIGN.md."

If no DESIGN.md, omit this section but note it.

### 3. Test infrastructure

```markdown
**Target URLs**:
- Production: <url>
- Local dev:  <url> (how to start)
- Admin:      <url>

**Test accounts** (link to a separate ACCOUNTS file; never inline credentials in this doc if the repo is public):
- Admin:      <ref>
- Standard:   <ref>
- (other personas as relevant)

**Viewports**: 390px / 768px / 1280px (or per project)

**Tools**: <Playwright MCP, curl, browser DevTools, etc.>

**Screenshots**: <path convention>
```

**Credential rule:** if the repo is public, credentials live in a separate file (`docs/operations/TEST_ACCOUNTS.md` or `.env.test`) referenced by name, not inline. The registry says "Account: standard user" — the standard user's actual creds live elsewhere.

### 4. Feature entries

Group by tag. Each entry is ~15–25 lines.

---

## Entry format (required fields)

```markdown
### F<NN>: <Feature name>
- **URL**: <route(s) the feature lives at>
- **Auth**: <none | authenticated | role: admin | role: paid>
- **Account**: <reference to test account, or "any logged-in user", or "guest">
- **Preconditions**: <state the test environment must be in, e.g., "user has 0 bookmarks">
- **Functional test**:
  1. <step>
  2. <step>
  3. <verify network: METHOD /path returns <status>>
  4. <verify DOM: <selector> contains <text> | cookie <name> set | redirect to <url>>
- **Visual test**: <what to verify visually; reference DESIGN.md sections>
- **Pass criteria**: <bullet list of conditions for PASS. All must hold.>
- **Tags**: [auth] [public] [admin] [mobile] [payment] [...]
```

### Required fields

- **ID** (`F01`, `F02`, ...) — stable, never reused
- **Feature name** — human-readable
- **URL** — primary route (or routes)
- **Auth** — what authn/authz is required
- **Functional test** — numbered, deterministic steps
- **Pass criteria** — explicit list of what makes this PASS
- **Tags** — at least one

### Optional fields

- **Account** — if Auth is not "none"
- **Preconditions** — if the test needs setup beyond auth
- **Visual test** — if the feature has a UI surface (skip for pure-API features)
- **Mobile parity** — name of the corresponding mobile screen, if the feature exists in both web and mobile
- **Owner** — team or person responsible for this feature
- **Backend route** — explicit reference to the handler file:line; useful for the sync audit
- **Known issues** — link to issues that affect this feature; PASS criteria may need to tolerate them

### Forbidden fields

- **Inline credentials** in a public repo
- **Test results** — those go in run reports, not the registry
- **Implementation notes** — those go in code comments or architecture docs

---

## ID convention

- **`F` prefix + zero-padded number**: `F01`, `F02`, ..., `F100`.
- **IDs are append-only.** Never renumber. If `F03` is removed, `F03` is retired (record as "removed YYYY-MM-DD" in a graveyard section at the bottom, or just leave the gap).
- **No ID reuse.** A new feature gets the next number.
- **Optional category prefix**: `FA01` (auth), `FP01` (public), `FM01` (mobile-only) if you want IDs to carry semantics. Pick one scheme and stick with it.

## Tag convention

Tags are lowercase, bracketed, single-word. Common tags:

- **Surface**: `[public]`, `[authenticated]`, `[admin]`, `[mobile]`, `[api]`
- **Domain**: `[auth]`, `[payment]`, `[search]`, `[settings]`, `[onboarding]`
- **Risk**: `[critical]` (revenue / security / data-loss path)
- **Status**: `[flaky]` (known to fail intermittently — investigate, don't auto-fail run)

Multiple tags per entry. The fanout invocation (`test all [admin]`) only works if tagging is consistent.

---

## Invocation patterns

A registry following this spec supports invocations like "test feature F03," "test all features tagged [critical]," "run visual tests on all [public] at viewports 390/768/1280," and "audit the registry against code for drift."

For paste-ready prompts and flag conventions, see `INVOCATIONS.md` (FEATURE_REGISTRY section). This spec doc shows the registry's *shape*; INVOCATIONS shows the patterns that consume it.

---

## Sync audit (registry ↔ code)

The registry drifts. Run this audit quarterly, or before relying on the registry as a release gate:

1. **Routes in registry but not in code**
   - Extract every URL from registry entries
   - Cross-reference against the registered backend routes (use Phase 1.2 of `audits/STUB_AND_COMPLETENESS.md`)
   - Each unmatched URL is a registry entry to remove or update

2. **Routes in code but not in registry**
   - List backend routes
   - Filter to user-facing routes (not internal/healthz/etc.)
   - Each one without a registry entry is a coverage gap

3. **Mobile parity drift**
   - For each entry with `Mobile parity: <ScreenName>`, verify that screen still exists
   - For each mobile screen, verify there's a registry entry that points at it

Report goes to `docs/reports/REGISTRY_DRIFT_<YYYY-MM-DD>.md`.

---

## Generation and per-feature additions

For paste-ready prompts (cold bootstrap of the full registry, per-feature add during a PR), see `INVOCATIONS.md` (FEATURE_REGISTRY section). The generator must follow these spec-defined rules:

- Discovery uses Phase 1 commands from `audits/STUB_AND_COMPLETENESS.md`
- Functional steps must be specific — DOM selectors, network calls, expected statuses, not "verify it works"
- Group by tag; default tags: `[public]`, `[authenticated]`, `[admin]`, `[mobile]`, `[api]`
- Reference `DESIGN.md` from the design standards section if it exists
- Never invent functional steps you cannot verify from code; mark unclear Pass criteria as "TBD — needs product input"
- Show registries in chunks of 5 features for review before committing the full file
- Per-feature additions use the next available ID and match existing tag conventions

---

## Anti-patterns

- **Vague functional steps.** "Click the button and verify it works" is not a step. "Click `button[data-test=submit]`, verify network POST `/api/x` returns 200, verify URL changes to `/success`" is.
- **Pass criteria that includes the test steps.** Pass criteria is the *outcome* (token issued, redirect happened, no JS errors). Not "the steps completed."
- **Registry as design doc.** This file describes what exists, not what should exist. Aspirational features go in an issue tracker.
- **Inline credentials in public repos.** Reference, don't inline.
- **Stale entries kept "in case."** If the feature is gone, delete the entry. Use the graveyard section for traceability if you need a record.
- **Unbounded entries.** Each entry should fit on one screen. If a feature needs more than 25 lines, it's actually multiple features — split into `F12a`, `F12b` or assign new top-level IDs.

---

## Relationship to other docs

- **`AUDIT_CONTEXT.md`** — institutional knowledge overlay; FEATURE_REGISTRY is structured data. Different file.
- **`DESIGN.md`** — visual source of truth; FEATURE_REGISTRY references it for visual tests.
- **Universal audit docs** — `audits/STUB_AND_COMPLETENESS.md` and `audits/DOCS_DRIFT.md` cross-check against the registry. The registry is *both* a test suite definition and an audit input.
- **Test code (`tests/e2e/`, `tests/integration/`)** — the registry is the *spec* for what should be tested; test code is the implementation. They can diverge; the registry sync audit catches that.
