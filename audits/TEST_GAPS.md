# Test Coverage Gap Audit

## Purpose

Find **scenarios** the test suite would miss — not lines uncovered. Line coverage tells you what code ran; this audit tells you what bugs would slip through. The questions:

- Which classes of bugs (concurrency, encoding, auth, partial failure, large input) have no test guarding them?
- Which integration boundaries (frontend↔backend, service↔service, app↔DB) are tested only in isolation?
- Which "happy path" tests would still pass if the feature was broken in a realistic way?

## When to run

Before a release that touches a critical path; after an incident, to find sibling bugs the test suite also wouldn't catch; quarterly as a forcing function.

## Time estimate

60–90 min.

## Output

`docs/reports/TEST_GAPS_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery

```bash
# Test framework(s)
ls jest.config.* vitest.config.* pytest.ini pyproject.toml playwright.config.* \
   cypress.config.* 2>/dev/null
grep -rln --include='*.go' '_test\.go$' . 2>/dev/null | head -5

# Test file count by tier
echo "Unit:";        find . \( -name '*_test.go' -o -name '*.test.ts' -o -name '*.test.tsx' \
                       -o -name '*.test.js' -o -name 'test_*.py' \) \
                       -not -path '*/node_modules/*' | wc -l
echo "E2E:";         find . \( -path '*/e2e/*' -o -path '*/cypress/*' -o -path '*/playwright/*' \) \
                       -name '*.ts' -o -name '*.js' 2>/dev/null | wc -l
echo "Integration:"; find . \( -path '*/integration*' -o -name '*.integration.*' \) \
                       -not -path '*/node_modules/*' 2>/dev/null | wc -l

# Run coverage if cheap
# (Only if CI typically does this — skip if it takes >5 min.)
```

Record: test framework(s), tier breakdown, where coverage reports live (if any).

---

## Phase 1: Critical Path Inventory

List the **5–10 most important user paths**. Examples: signup, login, password reset, primary CRUD action, payment, admin user management.

For each, ask three questions:

1. **Is it tested at all?** Does any test exercise this path end-to-end?
2. **Would a realistic break be caught?** If you mutated a key line in the handler, would a test fail?
3. **Are the failure modes tested?** Bad input, auth missing, dependency down, partial write.

Output a table:

| Path | Unit | Integration | E2E | Failure modes tested |
|---|---|---|---|---|
| Login | yes | yes | no | wrong password: yes; expired token: no; rate limit: no |

---

## Phase 2: Failure Mode Coverage

For the critical paths from Phase 1, check for tests covering each failure class:

### 2.1 Input edge cases

For each input field on a critical path:
- Empty / null / undefined
- Whitespace-only
- Maximum length (and length+1)
- Unicode / emoji / RTL
- Numeric: zero, negative, very large
- Date/time: past, future, boundary, invalid format
- Enum: unknown value

```bash
# Find tests that include edge-case inputs (heuristic)
grep -rEn --include='*test*' --include='*spec*' \
  -E '""|''|null|undefined|NaN|0xFF|emoji|"\xe2|0|-1|9999999' . \
  | grep -v node_modules | head -30
```

### 2.2 Concurrency

- Two users acting on the same resource simultaneously
- Same user double-submitting
- Optimistic-lock conflicts (if your DB has them)

```bash
grep -rEn --include='*test*' \
  -E 'concurrent|parallel|race|t\.Parallel|asyncio\.gather' . | grep -v node_modules
```

### 2.3 Authorization edge cases

- Unauthenticated user hits authenticated route
- Authenticated user hits authorized route (no role)
- User A acts on User B's resource (IDOR)
- Expired/revoked token

```bash
grep -rEn --include='*test*' \
  -E 'unauth|forbidden|401|403|expired_token|wrong.user' . | grep -v node_modules
```

### 2.4 Partial failure

- DB write succeeds, cache invalidation fails
- External API returns 5xx
- External API returns 200 with malformed body
- Network timeout mid-request

```bash
grep -rEn --include='*test*' \
  -E 'mock.*reject|mockRejected|side_effect.*Error|ConnectionError|Timeout' . | grep -v node_modules
```

### 2.5 Encoding / serialization

- JSONB read of value written by older code shape
- snake_case vs camelCase across boundaries
- Timezone handling (UTC vs local on read/write)

---

## Phase 3: Mutation Test (manual)

For 3 critical handlers, mentally mutate one line and ask: would any test catch it?

Common mutations:
- `if (x > 0)` → `if (x >= 0)`
- `||` → `&&`
- `return user` → `return adminUser`
- `WHERE owner_id = ?` → remove the WHERE
- `await save()` → remove the `await`

If no test catches the mutation, that path is **untested in any meaningful sense** even if line coverage shows green.

---

## Phase 4: Integration Boundary Tests

Most bugs live at boundaries. Look specifically for tests that cross them:

```bash
# Tests that use a real (or testcontainers) DB
grep -rEn --include='*test*' \
  -E 'testcontainers|real_db|integration|TEST_DATABASE_URL|sqlite::memory' . | grep -v node_modules

# Tests that run the actual server (not just call handlers directly)
grep -rEn --include='*test*' \
  -E 'supertest|httptest\.NewServer|TestClient|app\.test_client|requests\.get' . | grep -v node_modules

# Contract tests between frontend and backend
find . \( -name '*contract*' -o -name '*pact*' -o -name '*openapi*test*' \) \
  -not -path '*/node_modules/*'
```

A green unit suite with no integration tests means: every individual function works in isolation, but no test verifies they compose correctly.

---

## Phase 5: Mock Quality

Heavy mocking can hide real bugs.

```bash
# Count mocks per test file
grep -rln --include='*test*' --include='*spec*' \
  -E 'mock|jest\.fn|MagicMock|@patch|sinon\.stub' . | grep -v node_modules \
  | xargs -I {} sh -c 'echo "$(grep -cE "mock|jest\.fn|MagicMock|@patch" "{}") {}"' \
  | sort -rn | head -20
```

Tests with >10 mocks per file are often testing the mocks, not the code. Sample one and ask: if the mocked dependency changed its real behavior, would the test still pass?

Also flag:
- Tests that mock the database (mocks pass; migrations/queries break)
- Tests that mock the function under test (literally tautological)
- Tests that mock auth (auth bugs become invisible)

---

## Phase 6: Flaky / Disabled tests

```bash
grep -rEn --include='*test*' --include='*spec*' \
  -E 'skip|xit|xdescribe|@pytest\.mark\.skip|t\.Skip|todo' . | grep -v node_modules
```

Each disabled test is a known gap. Record why it was disabled (commit message, git blame).

---

## Severity rubric

| Severity | Criteria |
|----------|----------|
| **P0** | Critical path has no end-to-end test, OR realistic mutation passes the suite |
| **P1** | Auth/authorization edge cases not covered on a critical path; integration boundary untested |
| **P2** | Failure-mode coverage gaps (encoding, concurrency, partial failure) |
| **P3** | Edge-case input coverage gaps; tests heavy in mocks; disabled tests |

---

## Report template

```markdown
# Test Coverage Gap Audit — <DATE>

## Summary
- Critical paths reviewed: X
- Findings: X (P0: X, P1: X, P2: X, P3: X)

## Critical path coverage matrix
| Path | Unit | Integration | E2E | Failure modes tested | P-level |
|---|---|---|---|---|---|

## P0 — Untested critical paths
| Path | What's missing | What bug class would slip through | Suggested test |
|---|---|---|---|

## P1 — ...

## Mutation test results
- Handler: `<file>:<line>`
- Mutation tried: `<change>`
- Test result: PASSED (gap) / FAILED (good)

## Mock-heavy hot spots
| File | Mock count | Risk |
|---|---|---|

## Disabled tests
| File | Reason | First disabled |
|---|---|---|

## Recommendations
1. ...
```
