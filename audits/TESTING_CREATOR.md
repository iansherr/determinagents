# Testing Creator: High-Fidelity Verification Framework

## Purpose

A spec for building **executable verification suites that go beyond unit and integration tests** — covering the four tiers where real systems break under adversaries, partial failures, multi-actor concurrency, and tamper attempts.

This is a **creator** doc, not a read-only audit. The agent surveys the existing test surface, identifies gaps across the four tiers, and **implements and commits** the missing tests, simulations, and verifiers — with explicit checkpoints for human approval before shipping new test infrastructure.

This is the only doc in this directory that mutates the codebase. All others are read-only analyses.

## Prerequisites: run these audits first

This doc consumes the findings from two read-only audits. Don't duplicate their work here.

- **[TEST_GAPS.md](TEST_GAPS.md)** — scenario coverage of unit and integration tests (correctness). Its critical-path matrix and mutation-test findings are the input to Phase 0 here.
- **[SECURITY_PENTEST.md](SECURITY_PENTEST.md)** — the static-analysis half of adversarial. This doc adds the *executable* half (RBAC matrix tests, attestation challenges, fuzz inputs).

`DATA_FLOW_TRACE.md` is also valuable as input — it identifies where flows can break, which informs Tier 2 (Chaos) coverage.

If `TEST_GAPS.md` and `SECURITY_PENTEST.md` haven't been run, stop and run them. The reports they produce are the gap inventory this doc draws from.

## When to run

- Before shipping a feature with concurrency, money movement, or auth-sensitive paths.
- During architectural hardening sprints.
- After an incident, to install permanent regression coverage at the right tier.
- Before a security audit, to ensure adversarial controls are testable.


**Model tier**: `reasoning` — (Tier 3 simulation and Tier 4 forensics need real reasoning; Tiers 1-2 work on default.)

## Time estimate

Open-ended — this doc *implements* tests, so wall time scales with how many gaps exist. Plan in tier-sized chunks: a single tier for one service is ~half a day to a day.

## Output

1. New test files in the project's test tree (per the project's convention).
2. Optional new simulation harness at `simulation/<feature>/` if Tier 4 work is performed.
3. A report at `docs/reports/TEST_VERIFICATION_<service>_<YYYY-MM-DD>.md` documenting what was added, what wasn't, and why.

---

## The four tiers

Each tier answers a different question. A service is "verified" only when it has live coverage at every tier where the question is non-trivial for it. Correctness — "is the math right?" — is covered by `TEST_GAPS.md` and is not duplicated here.

| Tier | Question | Common artifacts |
|------|----------|------------------|
| **1. Adversarial** | Can it be bypassed or coerced? | RBAC matrix tests, attestation challenges, fuzz harnesses |
| **2. Chaos** | Does it survive failure? | Provider-down simulations, circuit-breaker tests, survival mode |
| **3. Simulation** | Does it work in a cluster? | Multi-node Docker harness, leader-election + thundering-herd tests |
| **4. Forensics** | Is tampering detectable? | Integrity / fracture tests, honeytoken alarms |

Not every service needs all four. A pure-CRUD service may legitimately stop at Tier 1. A service handling payments, secrets, or distributed state needs all four.

---

## Phase 0: Discovery

Survey the existing test surface and risk surface before implementing anything.

### 0.1 Test infrastructure

```bash
# Test frameworks present
ls jest.config.* vitest.config.* pytest.ini playwright.config.* cypress.config.* 2>/dev/null
grep -rln '_test\.go' . 2>/dev/null | head -3
grep -rln --include='*.py' -E '^def test_|^class Test' . 2>/dev/null | grep -v venv | head -5

# Existing simulation / chaos / multi-node tooling
find . -type d \( -name 'simulation' -o -name 'chaos' -o -name 'integration' \
  -o -name 'e2e' -o -name 'multi-node' -o -name 'fixtures' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' | head -10

# Container orchestration that could host multi-node sims
ls docker-compose*.yml docker-compose*.yaml Dockerfile* 2>/dev/null
find . -path '*/k8s/*' -name '*.yaml' 2>/dev/null | head -10

# Fuzzing / property-testing libraries
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'hypothesis|fast-check|jsverify|gopter|go-fuzz|FuzzingOptions' . 2>/dev/null \
  | grep -v node_modules | head -10
```

Record: which tiers have any infrastructure today, which are unrepresented.

### 0.2 Git-aware risk identification

Areas of recent churn or recent bug-fixing are where physics bugs hide.

```bash
# Last 50 commits — look for fixes related to concurrency, timing, syncing, permissions
git log -n 50 --pretty=format:'%h %s' \
  | grep -iE 'race|concurren|deadlock|timeout|retry|sync|permission|auth|rbac|leak'

# High-churn files (frequent edits = high cognitive load = bug habitat)
git log --since='3 months ago' --name-only --pretty=format: 2>/dev/null \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -20

# Files touched in revert/hotfix commits — historical incident sites
git log --since='1 year ago' --pretty=format:'%H %s' 2>/dev/null \
  | grep -iE 'revert|hotfix|incident|outage' | head -10
```

For each pattern surfaced, note: which tier should permanently cover this so it never regresses.

### 0.3 Critical-path inventory

Carry forward the critical-path list from the `TEST_GAPS.md` report. For each path, plan tier coverage:

| Path | Tier 0 (TEST_GAPS) | Tier 1 Adversarial | Tier 2 Chaos | Tier 3 Simulation | Tier 4 Forensics |
|------|-------------------|--------------------|--------------|-------------------|------------------|
| Login | unit ✓ | RBAC matrix? | refresh-token expiry? | concurrent login same user? | session-tamper test? |
| Payment | ... | ... | ... | ... | ... |

Empty cells are candidate gaps. Not every cell needs to be filled — record the rationale where a tier is intentionally skipped.

---

## Phase 1: Adversarial (Tier 1)

Static analysis lives in `SECURITY_PENTEST.md`. This tier adds **executable** adversarial tests.

### 1.1 RBAC matrix

For every (role × resource × action) triple, a test that proves enforcement.

**Discovery:**

```bash
# Roles defined in the codebase
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E '\b(roles?|Role)\s*[:=]\s*["'\''\[]' . | grep -v node_modules | grep -v test

# Existing RBAC tests
grep -rEn --include='*test*' \
  -E 'forbidden|unauthorized|403|401|wrong.role|rbac' . | grep -v node_modules
```

**Implementation mandate:**

Generate a parameterized integration test that iterates `(role, action, resource) → expect(allow|deny)`. Tests should hit the real router, not mocked authz. Failure mode: a new role added without a corresponding row in the matrix should fail loudly.

### 1.2 Attestation / token integrity

For services holding high-value keys or accepting privileged tokens, implement a challenge-response test that proves:

- A correctly-signed token is accepted
- A token signed with the wrong key is rejected
- A token with the `none` algorithm is rejected
- A token past expiry is rejected
- A token with a tampered claim payload (kept signature, modified body) is rejected

**Discovery:**

```bash
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'jwt\.(Parse|verify|decode)|verifyToken|VerifyAttestation' . \
  | grep -v node_modules | grep -v test
```

For each parse site, verify there's a corresponding negative test. If not — mandate.

### 1.3 Fuzz / boundary inputs on attack surfaces

For every endpoint accepting user-supplied strings/bytes (search queries, file uploads, JSON bodies), add at minimum:

- Empty body / empty string
- 10MB payload
- Unicode + RTL + null bytes
- JSON with deeply nested objects
- JSON with maliciously-typed fields (string where number expected)

Property-based testing libraries (Hypothesis for Python, fast-check for TS, gopter for Go) are preferred over hand-written cases when the input space is large.

### 1.4 Implementation checkpoint

Before writing tests, present the agent's plan: which roles, which endpoints, which fuzz strategies. Get approval. Then implement.

---

## Phase 2: Chaos & Resilience (Tier 2)

Distributed systems fail at boundaries. Prove the system survives "the bad day."

### 2.1 Dependency-down simulations

For each external dependency (DB, object store, external API, message queue, cache), implement a test that:

1. Brings the dependency to an unhealthy state (compose down, iptables drop, mock 503 responses)
2. Issues a real user request through the system
3. Verifies the response is **bounded** (returns within timeout, returns a graceful error, or enters survival mode) — never hangs, never returns success-shaped garbage

**Discovery:**

```bash
# External dependencies
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'http\.Client|http\.(Get|Post)|requests\.(get|post)|fetch\(|axios|RedisClient|Pool\(|connect\(' . \
  | grep -v node_modules | grep -v test | head -30

# Existing timeout configurations
grep -rEn -E 'Timeout|deadline|AbortController' --include='*.go' --include='*.py' --include='*.js' --include='*.ts' . \
  | grep -v node_modules | grep -v test | head -30

# Existing circuit breaker / retry libraries
grep -rEn -E 'circuit.?breaker|hystrix|resilience4j|tenacity|retry' . | grep -v node_modules | head -20
```

### 2.2 Survival mode

If a critical dependency is unavailable, the service should enter a documented degraded state (read-only, queue writes, serve cache) — never silent corruption, never crash loop.

**Implementation mandate:** for each critical dependency, define and test the survival mode. Document it in the service's runbook.

### 2.3 Timeout & retry verification

```bash
# Outbound HTTP calls without explicit timeout
grep -rEn -B2 -A5 --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'http\.(Get|Post|Do)|requests\.(get|post)|fetch\(' . \
  | grep -v node_modules | grep -v test | head -50
# Inspect each: is there an explicit timeout in scope?
```

Each outbound call without a timeout is a Tier-2 finding. Add a timeout, then add a test that verifies it triggers correctly.

---

## Phase 3: Multi-Node Simulation (Tier 3)

The "physics" tier — bugs that only appear when multiple instances of the system interact.

Skip this tier entirely if the service is genuinely single-instance and will remain so. Most production services are not.

### 3.1 Simulation harness

Create `simulation/<feature>/` with:

- `docker-compose.yml` (or k8s manifest) describing N instances of the service plus shared state (DB, message broker)
- A test runner that brings the cluster up, exercises the scenario, verifies invariants, brings it down
- Deterministic teardown — leftover state poisons the next run

### 3.2 Required scenarios

For services running >1 instance:

- **Big bang start**: all N instances start simultaneously. Verify no duplicate initialization, no leader-election thrash, no migration deadlock.
- **Concurrent same-user action**: two instances handle the same user's two simultaneous requests. Verify no double-write, no lost update.
- **Rolling restart under load**: kill instances one at a time during steady traffic. Verify in-flight requests complete or fail cleanly.
- **Partition / split-brain** (if applicable): one half can't reach the other. Verify the system doesn't double-acknowledge.

### 3.3 Machine-to-machine handshakes

For OIDC / mTLS / service-to-service auth flows: implement a test that completes the handshake **without human interaction** in a clean cluster start. If a flow needs a human in the loop on first boot, it's a Tier-3 finding.

---

## Phase 4: Forensics & Tamper Detection (Tier 4)

Required for: services holding audit logs, immutable history, signed records, or compliance-relevant state. Optional otherwise.

### 4.1 Fracture test

Manually mutate a row in persistent state. Run the integrity check. Assert that the check fails and the alert fires.

```bash
# Find integrity / hash / signature verification code
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'verify(Hash|Signature|Integrity)|hmac|crypto\.(verify|hash)' . \
  | grep -v node_modules | grep -v test | head -30
```

For each verification site, there should be a corresponding fracture test. If absent, mandate.

### 4.2 Honeytoken / canary

Plant a canary credential or row. Implement an automated test that:

1. Triggers the canary (simulating an attacker reading it)
2. Verifies the alert path fires (page, log line, metric)
3. Confirms the alert payload contains enough forensic context to investigate

### 4.3 Audit log immutability

If the service writes audit logs:

- Test: an audit log entry cannot be deleted via the application's own API
- Test: a tamper to the audit table itself is detectable on next integrity check

---

## Implementation rules

- **Survey before writing.** Phase 0 is mandatory; the report quality depends on knowing what already exists.
- **Stop and confirm before adding new test infrastructure.** New `simulation/` dirs, new chaos tooling, new property-testing dependencies — present the plan, get approval, then implement.
- **One tier per session unless told otherwise.** Tiers are non-trivial; bundling them into one session yields shallow work in all of them.
- **Each test must fail before it passes.** Write the test, run it, see it fail (or — for new feature tests — confirm the absence of the assertion would have masked a real bug). Then implement / fix. Then commit.
- **No mocks at boundaries the test is meant to verify.** A Tier-3 dependency-down test that mocks the dependency proves nothing about real outages.
- **Tests carry a tier tag in their name or location** so future audits can re-survey easily: `tier3_chaos_db_down_test.go`, `simulation/payment-flow/`, etc.

## Severity rubric

For findings (gaps in coverage), not for test failures:

| Severity | Criteria |
|----------|----------|
| **P0** | Critical path has no Tier-1 coverage on a security-sensitive control, OR no Tier-2 coverage on a money/data-loss path |
| **P1** | Tier-2 dependency without survival mode + test; Tier-3 multi-instance scenario unaddressed on a service that runs >1 replica |
| **P2** | Tier-1 fuzz/boundary coverage missing on a public input surface; Tier-4 absent on a service that should have it |
| **P3** | Tier-tagging conventions inconsistent; outbound calls without timeouts on non-critical paths |

---

## Report template

Reports must also include the universal sections from `specs/FORMAT.md` — `## Severity rubric (this audit)` (copied verbatim from this doc's rubric) and `## Next steps` (paste-ready RESOLVE_FROM_REPORT invocation with this report's path filled in). Audit-specific structure below:

```markdown
# Test Verification Report — <service> — <DATE>

## Prerequisite reports referenced
- TEST_GAPS:        `docs/reports/TEST_GAPS_<DATE>.md`
- SECURITY_PENTEST: `docs/reports/SECURITY_AUDIT_<DATE>.md`

## Tier coverage matrix
| Tier | Status before | Status after | Artifacts created |
|------|---------------|--------------|-------------------|
| 1. Adversarial | [LIVE / PARTIAL / ABSENT] | ... | `tests/rbac_matrix_test.go`, `tests/jwt_negative_test.py` |
| 2. Chaos       | ... | ... | `tests/chaos/db_down_test.go` |
| 3. Simulation  | ... | ... | `simulation/payment-flow/` |
| 4. Forensics   | ... | ... | `tests/integrity/fracture_test.go` |

## Phase 0 findings
- High-churn files: ...
- Recent fix-pattern incidents: ...
- Critical paths surveyed: ...

## Gaps closed (P0 / P1)
| Gap | Tier | Test added | Commit |
|-----|------|-----------|--------|

## Gaps remaining (P2 / P3)
| Gap | Tier | Reason deferred | Issue / owner |
|-----|------|----------------|---------------|

## Patterns observed
<2–3 paragraphs: where the system's "physics" surface is densest, recommended ongoing investment.>

## Recommendations
1. ...
2. ...
```
