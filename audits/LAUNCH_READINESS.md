# Launch Readiness Audit (MVP go-live gate)

## Purpose

Enumerate **every element a service needs to launch** — across visual UI, backend/networking, security, UX, demand/instrumentation, and business operations — then drive each element through a lifecycle: **documented → stubbed → verified**. Produces a single `LAUNCH_MANIFEST.md` where every requirement has a status and a blocker severity, so "are we ready to launch?" becomes a hash key into a structured artifact rather than a vibe.

This is **not** the P0 check. The P0 check asks "is the critical path working right now?" This audit asks "is *everything an MVP requires to responsibly go live* present, stubbed, or knowingly deferred?" — including the elements that don't break a demo but sink a launch: missing privacy policy, no guest checkout, no analytics, no error monitoring, no support channel, no rollback plan, no accessibility floor, no localization plan, no abuse controls, and no privacy/data map. It is broad and methodical by design.

The failure mode it prevents: launching with the happy path green and discovering post-launch that there's no way to track conversion, no legal terms, no password-reset email, no 500 page, and no way to roll back.

## Mode: Read-Only (mutating Phase 8 stub generation and resolve step, both approval-gated)

## When to run

Before any MVP or public launch; before opening a private beta to external users; before a payments go-live. Re-run as a gate at each launch milestone. **Phases 1–7 (the six-plus-ops lenses) are read-only.** Phase 8 (stub generation) is `[MUTATING]` and opt-in.

**Model tier**: `default` — cross-layer code understanding and checklist reasoning. Use `reasoning` for the demand/business-ops lenses on a novel domain where the required elements aren't obvious; `fast` is fine for a re-run that just re-verifies an existing manifest.

**Launch expectation**: record whether the launch is single-language or multilingual. Localization is always reported; whether it is required is a launch judgment derived from that expectation and the product scope, not a separate stored fact.

## Time estimate

Standard (cold, full manifest): ~60–120 min depending on surface. Re-verify of an existing manifest: ~20 min. Scope with `--phases=N,M`, `--lens=<name>`, or `--max-time=Xm`.

## Output

- **Working artifact**: `docs/determinagents/LAUNCH_MANIFEST.md` — the living checklist, updated in place across runs.
- **Report**: `docs/reports/LAUNCH_READINESS_<YYYY-MM-DD>.md` — the point-in-time go/no-go with blockers.

---

## The lifecycle (what "ready" means)

Every element in the manifest is in exactly one state. The audit's job is to move elements rightward and to refuse launch while any blocker sits left of `Verified`.

| State | Meaning | How it gets here |
|-------|---------|------------------|
| **Missing** | Required, not present, not even stubbed. | Discovery found a gap. |
| **Stubbed** | A placeholder exists so the absence is explicit and non-silent (e.g., a `/privacy` route returning a TODO page, a feature flag defaulting off, a `501 Not Implemented` handler). | Phase 8, or the team. |
| **Documented** | The requirement is written down with an owner and an acceptance check, even if not built. Deferrals are *documented decisions*, not oversights. | Phases 1–7 always do this. |
| **Verified** | Built, and confirmed working against its acceptance check (command run, flow walked, screenshot taken). | Phase 9. |
| **Deferred** | Explicitly out of MVP scope, recorded with rationale and owner. Not a blocker. | Human decision, captured in manifest. |

Rule: **nothing is silently Missing.** A required element is either Verified, or it is Stubbed/Documented/Deferred with an owner. Silent absence is itself a P0 finding.

---

## How this audit refuses to forget (the anti-amnesia contract)

The whole point of this harness is that an agent — or a person — *cannot* quietly skip something. The prompt is deliberately small ("walk the catalog, set each item's state in the manifest"); the rigor lives in the structure below, not in the agent's memory. Five mechanisms make completeness enforceable:

1. **The manifest is external memory, not the agent's working set.** The catalog (Phases 1–7) is the canonical list. Every catalog item MUST appear as a row in `LAUNCH_MANIFEST.md` with a state. The agent never has to "remember" 40 checks — it iterates a written list and records each outcome. A check it never ran isn't gone; it's a row still marked `Missing`.

2. **Coverage invariant (the completeness check).** A run is only valid if `count(manifest rows) >= count(catalog items not marked N/A)`. Before finalizing, the agent computes, per lens: catalog items vs. manifest rows. **Any lens with fewer rows than catalog items, or zero rows, means the agent skipped it — that is itself a B1 finding ("lens X under-covered"), not a silent pass.** The summary table's per-lens counts make this visible at a glance.

3. **Completeness critic (final pass).** After the lenses, the agent runs one explicit self-interrogation and writes the answers into the report:
   - Which catalog items have no manifest row? (→ add them as `Missing`)
   - Which lenses produced zero or suspiciously few rows? (→ re-run that lens)
   - Which `Verified` items lack a captured evidence artifact? (→ downgrade; they aren't verified)
   - What did Discovery reveal about *this* service that isn't in the generic catalog? (→ add domain-specific rows)
   - What am I assuming is fine without having checked? (→ make it a row)

4. **Phaseable + resumable, so long runs don't drown.** Each lens runs independently (`--lens=backend`). The manifest persists between runs and across context-window resets, so a run that stops halfway loses nothing — the next run reads the manifest and continues from whatever is still `Missing`/unverified. This is what lets the loop run methodically over many sessions without the agent "losing its place."

5. **Idempotent re-runs.** Re-running never starts over: it re-reads the manifest, re-checks only stale/unverified rows, and recomputes the scorecard. Running it twice on an unchanged repo produces the same manifest. Determinism is what makes it trustworthy as a gate.

The agent's standing instruction, in full: *iterate the catalog; for every item write or update one manifest row with a state and evidence; never leave a catalog item without a row; finish with the completeness critic.* Everything else is data in this doc, not load on the agent.

---

## Phase 0: Discovery

Learn the service before judging it. No hardcoded paths.

```bash
# Stack & entry points
ls package.json go.mod pyproject.toml Cargo.toml Gemfile pom.xml 2>/dev/null
find . -maxdepth 3 \( -name 'main.*' -o -name 'app.*' -o -name 'server.*' -o -name 'index.*' \) \
  -not -path '*/node_modules/*' -not -path '*/vendor/*' | head -20

# Routes / pages / endpoints (frontend + backend surface)
grep -rEn "route|router|\.get\(|\.post\(|app\.(get|post)|@(Get|Post)Mapping|http\.Handle" \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.go' --include='*.py' . \
  | grep -v node_modules | head -40

# Deployment / runtime surface
ls Dockerfile docker-compose.yml wrangler.toml wrangler.jsonc vercel.json netlify.toml 2>/dev/null
find . -path '*/.github/workflows/*' -name '*.yml' 2>/dev/null
find . \( -name '*.tf' -o -path '*k8s*' -o -name '*.helm' \) -not -path '*/node_modules/*' | head -10

# Does it take money? Does it have accounts? (drives which lenses are mandatory)
grep -rEnl "stripe|paypal|checkout|braintree|paddle|lemonsqueezy" . | grep -v node_modules | head
grep -rEnl "login|signup|auth|session|jwt|oauth" --include='*.ts' --include='*.go' --include='*.py' . \
  | grep -v node_modules | head

# Existing legal / ops surface
ls -d docs legal public 2>/dev/null
grep -rEnl "privacy|terms|gdpr|ccpa|cookie" . | grep -v node_modules | head

# Verification credentials source (needed by Phase 9 to walk authed/tiered flows)
ls docs/operations/TEST_ACCOUNTS.md docs/TEST_ACCOUNTS.md .env.test 2>/dev/null
grep -rEill "test account|test.?credential|seed.?(user|data|account)|admin@|qa@" \
  --include='*.md' docs 2>/dev/null | head
```

**Record in the manifest header:**
- What this service *is* (one sentence) and what "launch" means for it (public web app / private beta / payments go-live / API GA).
- Stack, deploy target, primary user-facing URLs.
- Expected launch language state: single-language / multilingual / unknown. The audit uses this to judge whether localization is a required launch surface or a report-only indicator.
- **Which lenses are mandatory vs N/A.** A static marketing site doesn't need a payments lens; an API product doesn't need a guest-checkout flow. Mark N/A lenses explicitly — an N/A is a decision, not a skip.

---

## The canonical launch catalog (ground truth)

Phases 1–7 each walk one lens. The catalog below is the **ground truth** — the audit iterates this list and, for each item, determines its state in *this* service. Treat unchecked items as `Missing` until proven otherwise. Add domain-specific items during Discovery; never silently drop a catalog item — mark it `Deferred` or `N/A` with a reason.

### Phase 1 — Visual / Frontend UI (the "visual UI expert" lens)

Goal: the product looks finished and behaves correctly at every state and viewport, not just the demo path.

Catalog:
- [ ] Responsive at all documented breakpoints (no clipping/overlap/scroll-trap) — defer detail to `UX_DESIGN_AUDIT.md`
- [ ] **Empty states** for every list/collection ("no items yet" not a blank box)
- [ ] **Loading states** for every async surface (skeleton/spinner, no layout jump)
- [ ] **Error states** in the UI (failed fetch shows retryable error, not a frozen screen)
- [ ] **404 page** and **500 / generic error page** exist and are branded
- [ ] Favicon, app title, social/OG meta tags, app icons (PWA/mobile if applicable)
- [ ] No placeholder content shipping (lorem ipsum, "Coming soon", TODO copy, broken images)
- [ ] Accessibility floor: keyboard access, visible focus, alt text, contrast, reduced-motion behavior — defer detail to `UX_DESIGN_AUDIT.md` Phase 7
- [ ] Console is clean (no errors/warnings) on the core flows

```bash
# Placeholder content that must not ship
grep -rEn "lorem ipsum|coming soon|TODO|FIXME|placeholder|XXX" \
  --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' . | grep -v node_modules | head -40
# Error/empty/404 surfaces present?
grep -rEnl "404|not.?found|NotFound|ErrorBoundary|500|empty.?state|EmptyState" \
  --include='*.tsx' --include='*.jsx' --include='*.ts' . | grep -v node_modules | head
# Meta / favicon
grep -rEn "og:|twitter:|<title>|favicon|apple-touch-icon|manifest.json" \
  --include='*.html' --include='*.tsx' . | grep -v node_modules | head
```

### Phase 2 — Backend & Networking (the "backend networking engineer" lens)

Goal: the service stays up, fails safely, and you can see what it's doing.

Catalog:
- [ ] **Health check / readiness endpoint** exists and is wired to the deploy platform
- [ ] **HTTPS/TLS** enforced; HTTP redirects to HTTPS; HSTS where applicable
- [ ] **CORS** policy is explicit (not `*` on credentialed endpoints)
- [ ] **Rate limiting / abuse protection** on public + auth endpoints
- [ ] **Timeouts & retries** on every outbound call (no unbounded waits)
- [ ] **Graceful degradation** when a dependency (DB, cache, third-party API) is down
- [ ] **Error monitoring** wired (Sentry/equiv) — uncaught errors are captured, not lost
- [ ] **Structured logging** with request IDs; no secrets/PII in logs
- [ ] **Environment config** via env/secrets manager — no hardcoded secrets, prod/staging separated
- [ ] **Database**: migrations runnable forward, backups configured, connection pooling bounded
- [ ] **Rollback plan**: how to revert a bad deploy; previous version deployable
- [ ] **Scaling headroom**: known capacity ceiling — defer detail to `RESOURCE_CAPACITY.md`

```bash
grep -rEnl "/health|/healthz|/readyz|/ping|/status" . | grep -v node_modules | head
grep -rEn "cors|Access-Control-Allow-Origin" . | grep -v node_modules | head
grep -rEn "Sentry|init\(|captureException|datadog|newrelic|opentelemetry" . | grep -v node_modules | head
grep -rEn "timeout|WithTimeout|AbortController|context.WithDeadline" . | grep -v node_modules | head -20
# Hardcoded secrets smell
grep -rEn "(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][A-Za-z0-9_\-]{12,}" \
  --include='*.ts' --include='*.go' --include='*.py' --include='*.js' . | grep -v node_modules | head
```

### Phase 3 — Security & Privacy posture

Goal: launching doesn't expose users or the business. Defer deep work to `SECURITY_PENTEST.md` / `SECURITY_HUNT.md`; this lens confirms the floor.

Catalog:
- [ ] AuthN/AuthZ on every non-public endpoint (no missing authz checks)
- [ ] Secrets not in the repo / not in client bundles; `.env` gitignored; key rotation possible
- [ ] Input validation on all user input; output encoding (XSS); parameterized queries (SQLi); protect against CSRF/SSRF/file-upload abuse — defer depth to `SECURITY_PENTEST.md` / `SECURITY_HUNT.md`
- [ ] **PII inventory + data lifecycle**: what personal data is collected, where it's stored, who can access it, retention rules, and whether deletion/export exists
- [ ] **Data deletion / export** path exists if GDPR/CCPA applies (even if manual at MVP)
- [ ] Cookie security: `Secure`, `HttpOnly`, `SameSite` set appropriately
- [ ] Dependency vulnerabilities triaged (`npm audit` / `govulncheck` / `pip-audit` clean or accepted)
- [ ] Security headers (CSP, X-Frame-Options, etc.) present

```bash
grep -rEn "Secure|HttpOnly|SameSite" . | grep -v node_modules | head
# Run whatever the stack supports
(npm audit --omit=dev 2>/dev/null || true); (govulncheck ./... 2>/dev/null || true); (pip-audit 2>/dev/null || true)
git ls-files | grep -E "\.env$|\.env\." | head   # secrets that should NOT be tracked
```

### Phase 4 — UX & Critical Flows (the "UX process" lens)

Goal: a real user — including a brand-new or signed-out one — can complete the core jobs end to end.

Catalog (instantiate against *this* product's jobs):
- [ ] **Onboarding / first-run** path is walkable by someone with zero prior state
- [ ] **Sign-up → verify → first value** flow completes (email verification actually sends/arrives)
- [ ] **Password reset** flow works end to end
- [ ] **Guest / signed-out path**: can a logged-out user do what they need? **Guest checkout** if commerce
- [ ] **Core conversion flow** (the one thing the MVP exists to do) completes without dead ends
- [ ] **Accessibility parity for the core flow**: keyboard-only usable, focus order sane, labels/alt text present, and the main path is screen-reader navigable
- [ ] **Payment flow** (if any): success, decline, and refund paths all handled — see Phase 6
- [ ] Confirmation + transactional emails actually deliver (receipt, welcome, reset)
- [ ] No dead ends: every error/empty state offers a next action
- [ ] Mobile parity for the core flow if mobile is in scope
- [ ] **Localization present** (or explicit N/A if this is a single-language launch): language tags, translated launch-facing content, locale assumptions, and fallback behavior are documented

For each critical flow, record it as a `FEATURE_REGISTRY.md` entry (deterministic steps + pass criteria) so it can be re-verified mechanically. This lens *feeds* the registry.

### Phase 5 — Demand & Instrumentation (the "demand understanding" lens)

Goal: at launch you can *see* demand and conversion. Launching blind is launching twice.

Catalog:
- [ ] **Analytics** installed and firing on key events (pageview + the core conversion event)
- [ ] **Conversion funnel** instrumented: you can answer "how many got from landing → signup → activation"
- [ ] **SEO basics**: title/meta/OG per page, `sitemap.xml`, `robots.txt`, canonical URLs, indexable
- [ ] **Acquisition tracking**: UTM/referrer capture so you know where users came from
- [ ] **Feedback channel**: a way for users to tell you something's broken (form, email, intercom)
- [ ] **Landing page** states the value prop and has a working primary CTA
- [ ] **Waitlist / capacity gate** if launching to limited capacity
- [ ] Status/uptime page or at least an incident comms plan
- [ ] **Abuse / anti-spam controls** on public forms and acquisition surfaces (signup, contact, waitlist, comments): rate limits, honeypot/CAPTCHA or equivalent, and a moderation path

```bash
grep -rEn "gtag|analytics|posthog|mixpanel|amplitude|plausible|segment|track\(" . | grep -v node_modules | head
ls public/robots.txt public/sitemap.xml robots.txt sitemap.xml 2>/dev/null
```

### Phase 6 — Business Operations & Legal (the "business operations" lens)

Goal: the business can lawfully and operationally sustain the launch.

Catalog:
- [ ] **Privacy Policy** published and linked (mandatory if collecting any personal data)
- [ ] **Terms of Service** published and linked
- [ ] **Cookie consent / banner** if required by jurisdiction
- [ ] **Payments**: real merchant account (not test keys), tax handling, receipts, refund policy + mechanism
- [ ] **Pricing** page accurate and matches what the system actually charges
- [ ] **Support**: a monitored channel (email/helpdesk) and an SLA expectation set
- [ ] **Contact / company info** present (required in many jurisdictions for commerce)
- [ ] **Domain & email**: custom domain live, SPF/DKIM/DMARC set so transactional mail isn't spam
- [ ] **Privacy / data-processing inventory** current: subprocessors, data categories, access boundaries, and who owns the compliance answer
- [ ] **Retention / deletion / export operations** documented: how long data is kept, how account deletion works, and what a user export looks like
- [ ] **Consent / tracker governance**: cookie banner or equivalent consent logging if analytics/ads trackers are active
- [ ] **Accounts/billing ownership**: who owns the cloud/payment/domain accounts is recorded
- [ ] **On-call / incident owner** named for launch window
- [ ] **Backups & data-retention** policy stated
- [ ] **Insurance / compliance** obligations identified (if regulated domain)

```bash
grep -rEnl "privacy|terms|refund|pricing|contact|support@" . | grep -v node_modules | head
# Live legal pages reachable? (if a base URL is known)
# curl -sI https://<host>/privacy https://<host>/terms | grep -E "HTTP/"
```

### Phase 7 — Operations & Launch-ops (the "can we run and survive it" lens)

Goal: the team can deploy it, see it, recover it, and afford it. This lens covers the things that don't live in application code and are therefore the easiest to forget — which is exactly why they get their own lens and their own catalog rows. Delegate depth to `RESOURCE_CAPACITY.md` (capacity/network pressure) and `DOCS_DRIFT.md` (doc freshness).

Catalog:
- [ ] **Entry-point doc current**: a `START_HERE.md` / `README` / runbook that a new operator can follow to run, deploy, and debug the service — and it matches reality (delegate drift detection to `DOCS_DRIFT.md`)
- [ ] **Architecture / network map** exists and is current: services, data stores, queues, third-party deps, and the ingress/egress paths between them. "Where does a request go and what can it reach?"
- [ ] **Network readiness**: DNS records correct, TLS cert valid with auto-renew + expiry alarm, CDN/edge configured, firewall/security-group ingress-egress rules reviewed, internal service-to-service connectivity verified
- [ ] **Deploy + rollback rehearsed** (not just documented): a deploy was actually performed to staging and a rollback actually executed at least once
- [ ] **Backups restore-tested** (not just configured): a restore was actually performed and verified — an untested backup is a B0, configured-but-untested is a B1
- [ ] **Migrations** run forward *and* roll back cleanly on a copy of prod-shaped data
- [ ] **Observability**: dashboards exist for the golden signals (latency, traffic, errors, saturation) and at least one **alert** is wired to a channel a human watches
- [ ] **Status page / incident comms** plan: how users are told when it's down
- [ ] **Cost / quota ceilings**: known monthly cost estimate; third-party API quotas + rate limits raised for launch traffic; billing alarm set
- [ ] **Third-party dependency readiness**: every external service has prod (not sandbox) credentials, an accepted ToS/SLA, and a defined behavior when it's down
- [ ] **Secrets management**: rotation runbook exists; no prod secrets in repo; staging/prod separated
- [ ] **Load / capacity check** at expected launch traffic — delegate to `RESOURCE_CAPACITY.md`
- [ ] **On-call / incident owner** named for the launch window with a contact path

```bash
# Entry-point + ops docs present and recently touched?
ls START_HERE.md README.md RUNBOOK.md docs/operations 2>/dev/null
git log -1 --format='%ci' -- START_HERE.md README.md 2>/dev/null
# Architecture/network map
grep -rEil "architecture|network.?map|topology|data.?flow" docs 2>/dev/null | head
find . \( -name '*.drawio' -o -name '*architecture*' -o -name '*diagram*' \) -not -path '*/node_modules/*' | head
# Deploy / rollback / backup surface
ls -d deployments infra docker 2>/dev/null
grep -rEil "rollback|restore|backup|disaster|runbook" docs deployments 2>/dev/null | head
# Observability + alerting
grep -rEil "dashboard|grafana|alert|prometheus|pagerduty|opsgenie|uptime|status.?page" . 2>/dev/null | grep -v node_modules | head
```

---

## Phase 8: Stub generation `[MUTATING]` (optional)

For each `Missing` element where a stub makes the absence explicit and safe, generate the minimal placeholder so nothing ships silently absent. Opt-in; only run in a disposable workspace (worktree/branch/container) per `specs/FORMAT.md` harness conventions.

Examples of legitimate stubs:
- A `/privacy` and `/terms` route returning a clearly-marked "DRAFT — pending legal review" page, tracked as a blocker.
- A `/healthz` endpoint returning `200 OK` if none exists.
- A branded `404`/`500` page replacing the framework default.
- An error-monitoring init guarded by an env var (no-op until the DSN is set).
- A feature flag defaulting **off** for any half-built surface, so it can't be reached in prod.

Each stub written MUST: (1) be obviously a stub (visible TODO/marker), (2) flip the manifest state `Missing → Stubbed`, (3) carry an owner and a follow-up. A stub is a way to make a gap *loud*, never a way to mark it done.

---

## Verification credentials (discover or scaffold) — prerequisite for Phase 9

Phase 9 walks real flows: signup → email-verify → first value, password reset, guest vs. authenticated paths, and any role/tier-gated surface. Those require persona credentials. Resolve the credential source **before** verifying — never inline credentials in the manifest or report.

Behavior, in order:

1. **Discover.** Use the Phase 0 result. The canonical location is `docs/operations/TEST_ACCOUNTS.md` (referenced by `specs/FEATURE_REGISTRY.md`); also accept `docs/TEST_ACCOUNTS.md` or `.env.test`. If found, the manifest's verification rows reference personas **by name** from it ("standard user", "admin", "lapsed subscriber") and the file is the only place actual secrets live.

2. **If absent, ask, then scaffold from the template below.** Do not invent credentials and do not write real secrets the agent generated; scaffold with `<PLACEHOLDER>` values and a TODO for a human to populate (or point at the project's seed-data fixtures). Stop and confirm before writing.

3. **Map personas to the flows that need them.** Auth/tier-gated catalog items in Phases 4–6 each name the persona required to verify them. A flow with no available persona is a verification gap → its manifest item cannot reach `Verified` and stays a blocker with reason "no test persona".

For an auth-bearing product, the *absence* of any repeatable test-account source is itself a **B1** — you cannot mechanically re-verify the loop without it.

**Credential hygiene (enforced):**
- **Public repo** → secrets must NOT be inline; the file holds references and the real values live in a secrets manager / `.env.test` that is gitignored. If real secrets are already committed in a public repo, that is a **B0** for the Security lens (Phase 3), independent of this audit's needs.
- **Private repo** → inline test-account secrets are acceptable only if scoped strictly to non-production test/verification accounts, never reused human or production credentials.
- The agent **redacts** all credentials from every report and Phase-8 artifact (`[REDACTED]`), per `specs/FORMAT.md`.

### TEST_ACCOUNTS template (scaffold when missing)

Write to `docs/operations/TEST_ACCOUNTS.md`:

```markdown
# Test & Verification Accounts — <service>

**Status**: Internal Use Only   **Last Updated**: <date>
Scope: test/verification only. Never reuse production or personal credentials.
If this repo is public, replace inline values with references to a secrets
manager or a gitignored .env.test; this file then holds names + references only.

## Environments
| Env | Base URL | Backend / DB | How to start |
|-----|----------|--------------|--------------|
| Local | http://localhost:<port> | <docker/seed-data ref> | <command> |
| Staging | <url> | <db ref> | — |
| Production (verify-only) | <url> | <db ref> | — |

## Personas (one row per role/tier the audit must verify)
| Persona key | Email / handle | Role / tier | State | Secret ref |
|-------------|----------------|-------------|-------|------------|
| admin | <PLACEHOLDER> | admin | active | <secret-ref or [TODO]> |
| standard | <PLACEHOLDER> | member | active | <secret-ref or [TODO]> |
| guest | (none) | unauthenticated | — | — |
| paid | <PLACEHOLDER> | <tier> | active | <secret-ref or [TODO]> |
| lapsed | <PLACEHOLDER> | <tier> | expired | <secret-ref or [TODO]> |
| banned | <PLACEHOLDER> | member | banned | <secret-ref or [TODO]> |

## Managing credentials
<how passwords are rotated / where seed data lives / how to provision a persona>
```

Tailor the persona rows to what Discovery found (a no-auth product needs only `guest`; a multi-tier product needs one row per tier, mirroring the states the code distinguishes).

---

## Phase 9: Verification

Methodically confirm each `Documented`/`Stubbed`/built element actually works, then flip to `Verified` or raise a blocker. This is where "checked carefully" lives. Pull personas from the verification-credentials source above; reference them by key, and redact secrets from every artifact.

For each manifest item with an acceptance check:
1. Run the check (command, curl, or walk the flow in a browser/Playwright).
2. Capture evidence (command output, status code, screenshot) under `docs/reports/LAUNCH_READINESS-artifacts/<date>/<item-id>/`.
3. Flip state to `Verified` only on observed success. Anything else stays a blocker with evidence of *why*.

Verification is observed, not assumed. "The route exists in code" is not verification; "`curl -sI /healthz` returned `200`" is.

---

## The readiness scorecard (the loop metric)

The manifest is deterministic state, so it yields a deterministic score. This score is what makes launch-readiness *loopable* — it gives an agent something measurable to drive toward, exactly as a benchmark does for `RECURSIVE_IMPROVEMENT`.

Computed from the manifest on every run (exclude `N/A` items from all denominators):

- **Blocker count** — `B0_open` and `B1_open` (severity-tagged items not in state `Verified` or `Deferred-with-signoff`). This is the headline.
- **Verified ratio** — `Verified / (total required − N/A)`, per lens and overall.
- **Coverage ratio** — `(total − Missing) / (total required − N/A)`. How much is at least documented/stubbed vs silently absent.

**Launch gate (the loop goal):** `B0_open == 0 AND B1_open == 0`. Verdict mapping:
- `GO` — `B0_open == 0 AND B1_open == 0`
- `GO-WITH-CONDITIONS` — `B0_open == 0 AND B1_open > 0` (each B1 owned with a deadline)
- `NO-GO` — `B0_open > 0`

These three numbers are written to the manifest header and emitted as signals (below). A run is "better" than the prior run iff `B0_open` then `B1_open` then `Missing` decreased without any new B0 appearing.

---

## Self-reinforcing loop

Launch readiness is a `RECURSIVE_IMPROVEMENT` loop (see `specs/LOOP_PROTOCOL.md`) where the manifest is the harness and the scorecard is the metric. One iteration:

1. **Measure** — run Phases 1–7 (read-only); update `LAUNCH_MANIFEST.md` in place. Recompute the scorecard.
2. **Report** — emit the dated report + signals JSON (below). Compute the delta vs the previous run's signals so the loop can see movement, not just state.
3. **Resolve** `[MUTATING]` — for the top open blockers, delegate to `audits/RESOLVE_FROM_REPORT.md` (per-finding approval, one commit per fix) or generate stubs via Phase 8. **Approval-gated; the loop proposes, the human or an explicitly-authorized orchestrator disposes.**
4. **Re-verify** — re-run Phase 9 against only the touched items; flip to `Verified` on observed success.
5. **Repeat** until a termination criterion.

**Termination criteria** (from `specs/LOOP_PROTOCOL.md`):
- `GO` reached (`B0_open == 0 AND B1_open == 0`) — the goal.
- `--max-iterations` hit.
- Diminishing returns: scorecard unchanged across two iterations (remaining blockers need human/product/legal input the loop can't supply — surface them and stop).
- Hard ceiling: a blocker that is a human decision (legal signoff, merchant-account approval) — mark `Deferred-with-signoff` *pending*, exclude from the loop's actionable set, keep it visible as `NO-GO`.

**Prime Mandate (correctness over score):** a resolution that flips one item to `Verified` but breaks a previously-`Verified` item (e.g., a CORS tightening that breaks the core flow) is a regression — revert it. The loop's score must never improve by introducing a new B0. Re-verify the *core conversion flow* after every mutating step, not just the touched item.

**Anti-gaming:** the score only counts `Verified` with captured evidence (Phase 9 artifact). Marking an item `Verified` without an artifact is invalid and must be caught on the next measure pass. Stubbing is not verifying — a `Stubbed` privacy policy is still a B0.

### Loop registry entry

Memorialize the loop in `docs/determinagents/LOOPS.md` (consumed by `LOOP_ORCHESTRATOR`) so it runs with the project's other loops:

```markdown
| ID | Target Area | Harness Command | Loop Type | Goal |
|---|---|---|---|---|
| `loop-launch` | `docs/determinagents/LAUNCH_MANIFEST.md` | `/determinagents launch-readiness re-verify` | `RECURSIVE_IMPROVEMENT` | Drive B0_open and B1_open to 0 (verdict GO) |
```

---

## Signal emission (reporting integration)

Every run writes a machine-readable companion that plugs straight into `specs/AUTOMATED_REPORTING.md`, so launch readiness shows up in the system digest and trends over time.

**Output:** `docs/reports/signals/LAUNCH_READINESS_<YYYY-MM-DD>.json`, following `specs/SIGNAL_SCHEMA.md` with `category: "readiness"`.

One signal per lens plus one overall. Example:

```json
{
  "version": "1.0",
  "generated_at": "<ISO8601>",
  "mode": "launch",
  "summary": { "overall_status": "triggered", "verdict": "NO-GO",
               "b0_open": 3, "b1_open": 5, "verified_ratio": 0.71 },
  "signals": [
    {
      "signal_id": "readiness-bizops-001",
      "category": "readiness",
      "metric": "b0_open",
      "current_value": 2,
      "baseline_value": 4,
      "delta": -2,
      "threshold": "== 0 to launch",
      "status": "triggered",
      "severity": "P0",
      "evidence_ref": "docs/determinagents/LAUNCH_MANIFEST.md:L01",
      "confidence": "high",
      "note": "privacy policy + refund mechanism still Missing"
    }
  ],
  "recommendations": [
    {
      "horizon": "immediate",
      "action": "Run /determinagents resolve --report=docs/reports/LAUNCH_READINESS_<date>.md scope=B0",
      "signal_refs": ["readiness-bizops-001"],
      "urgency": "high",
      "mutation_required": true,
      "approval_required": true
    }
  ],
  "unknowns": []
}
```

Because each run carries `baseline_value` and `delta` against the prior signals file, `auto-report --mode=trend` produces the **closing feedback element**: a readiness trajectory ("`62% → 78% → 91%`, `4 B0 → 1 B0`, ETA-to-GO at current rate") and re-emits the exact next invocation. That recommendation *is* the next loop input — which is what makes the loop self-reinforcing rather than just repeating.

> Note: `category: "readiness"` is an additive value for `specs/SIGNAL_SCHEMA.md` (currently `reliability|capacity|dependency|security|cost|drift`). Additive enum values are backward-compatible per that spec's compatibility policy.

---

## Severity rubric

Launch-blocker oriented. A "blocker" prevents go-live; everything else is post-launch backlog.

| Severity | Criteria | Action |
|----------|----------|--------|
| **B0 — Launch blocker** | Legal exposure (no privacy policy while collecting PII), security hole, unmitigated injection/XSS on a launch surface, data-loss vector, broken core conversion flow, no rollback, or a *silently Missing* required element. | Must be Verified or Deferred-with-signoff before launch. |
| **B1 — Launch risk** | Degrades launch but survivable for a short window: no error monitoring, no analytics on the core event, missing empty/error states on a primary surface, transactional email unverified. | Fix pre-launch or accept with a named owner and a deadline. |
| **B2 — Post-launch** | Real but deferrable: SEO polish, secondary-flow empty states, nice-to-have instrumentation. | Backlog with owner. |
| **B3 — Cosmetic / aspirational** | Won't affect launch outcome. | Track or drop. |

A B0 that the team chooses to launch with anyway is recorded as a **Deferred with explicit signoff** entry (who signed off, why, mitigation) — converting a silent risk into an owned decision.

---

## Launch Manifest template

The living artifact at `docs/determinagents/LAUNCH_MANIFEST.md`. One row per required element; updated in place across runs.

```markdown
# Launch Manifest — <service name>

**Launch definition**: <what go-live means here>
**Target date**: <date>   **Launch owner**: <name>
**Expected launch state**: single-language / multilingual / unknown
**Mandatory lenses**: Visual / Backend / Security / UX / Demand / BizOps
**N/A lenses**: <lens — reason>
**Last updated**: <date>

## Readiness summary
| Lens | Items | Verified | Stubbed | Documented | Missing | Deferred | Blockers (B0/B1) |
|------|-------|----------|---------|------------|---------|----------|------------------|
| Visual | | | | | | | |
| Backend | | | | | | | |
| Security | | | | | | | |
| UX | | | | | | | |
| Demand | | | | | | | |
| BizOps | | | | | | | |

## Elements
| ID | Lens | Requirement | State | Severity | Owner | Evidence / acceptance check | Notes |
|----|------|-------------|-------|----------|-------|-----------------------------|-------|
| L01 | BizOps | Privacy policy published & linked | Missing | B0 | | `curl -sI /privacy` → 200 | collecting email + payment data |
| L02 | Backend | /healthz wired to platform | Verified | — | ian | `curl -sI /healthz` → 200 | |
| ... | | | | | | | |

## Deferred with signoff (B0/B1 launching anyway)
| ID | Requirement | Signed off by | Rationale | Mitigation | Revisit by |
|----|-------------|---------------|-----------|------------|------------|
```

---

## Report template

Reports also include the universal sections from `specs/FORMAT.md` — the `audit:`/`date:` YAML frontmatter, `## Severity rubric (this audit)` (copied verbatim) and `## Next steps`. Audit-specific structure:

```markdown
---
audit: LAUNCH_READINESS
date: <YYYY-MM-DD>
---

# Launch Readiness — <DATE>

## Verdict
**GO / NO-GO / GO-WITH-CONDITIONS** — one line.

## Summary
- Manifest items: X (Verified X / Stubbed X / Documented X / Missing X / Deferred X)
- Blockers: B0: X, B1: X
- Lenses run: ...
- Time spent: ~Xh
- Expected launch state: single-language / multilingual / unknown
- Localization present: yes / partial / no
- Localization judgment: required / N/A / blocker severity

## Coverage / completeness (anti-amnesia check)
Per-lens catalog-vs-manifest coverage. A lens below 100% means items were skipped.
| Lens | Catalog items | Manifest rows | Coverage | Under-covered? |
|------|---------------|---------------|----------|----------------|
| Visual | | | | |
| Backend | | | | |
| Security | | | | |
| UX | | | | |
| Demand | | | | |
| BizOps | | | | |
| Operations | | | | |

Completeness critic answers:
- Catalog items with no manifest row: ...
- Lenses re-run due to under-coverage: ...
- `Verified` items lacking an evidence artifact (downgraded): ...
- Domain-specific rows added beyond the generic catalog: ...

## B0 — Launch blockers (must clear before go-live)
| ID | Lens | Requirement | Why it blocks | Evidence | Suggested fix |
|----|------|-------------|---------------|----------|---------------|

## B1 — Launch risks (clear or accept with owner)
| ID | Lens | Requirement | Risk | Owner | Deadline |
|----|------|-------------|------|-------|----------|

## Silently-missing elements found
Anything that was Missing with no stub/decision — the core value of this audit.

## Patterns observed
1–3 paragraphs: what category of readiness is systematically weak (e.g., "UX states are strong but ops/legal is entirely absent").

## Recommendations
Cross-cutting next actions beyond per-item fixes.
```

---

## Relationship to other audits

This audit is the **orchestrator/gate**; it delegates depth to the specialists rather than duplicating them:

- **Visual lens** → defers to `UX_DESIGN_AUDIT.md` for token/contrast/responsive detail.
- **Backend lens** → defers to `RESOURCE_CAPACITY.md` for capacity, `STUB_AND_COMPLETENESS.md` for phantom endpoints.
- **Security lens** → defers to `SECURITY_PENTEST.md` / `SECURITY_HUNT.md`.
- **UX lens** → *produces* `FEATURE_REGISTRY.md` entries for each critical flow, then those get verified mechanically.
- **Error handling** → defers to `ERROR_HANDLING.md` for silent-swallow detail.

Run those for depth; run this to know whether the *set* of things a launch requires is accounted for.
