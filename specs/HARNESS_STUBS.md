# Harness Stubs

## Purpose

A reference library of **copy-pasteable boilerplate** for common verification harnesses. Use these as the starting point when running `HARNESS_CREATOR.md` or adding a Phase 6 to an audit.

These stubs implement the **Resilience Rules** (Ghost Function avoidance, Redaction, Loop-based verification) by default.

---

## S1. UX / ComputedStyle Verify (Playwright)

Use this to verify `DESIGN.md` compliance.

```javascript
// tests/harness/ux_integrity.spec.js
const { test, expect } = require('@playwright/test');
const fs = require('fs');

const manifest = JSON.parse(fs.readFileSync('docs/reports/artifacts/canonical_manifest.json'));

test.describe('UX Integrity Loop', () => {
  manifest.tokens.forEach(token => {
    test(`Verify token: ${token.name}`, async ({ page }) => {
      await page.goto(process.env.TARGET_URL || 'http://localhost:3000');
      
      // Verification logic
      const value = await page.evaluate((name) => {
        return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
      }, token.name);

      // Redacted logging for PII/Secret safety
      console.log(`[VERIFY] ${token.name}: ${value}`);
      
      expect(value.toLowerCase()).toBe(token.expected.toLowerCase());
    });
  });

  test('Orphan/Ghost Variable Check', async ({ page }) => {
    await page.goto(process.env.TARGET_URL || 'http://localhost:3000');
    const variables = await page.evaluate(() => {
      // Find all CSS vars in :root
      // ... (logic to extract --*)
    });
    // Cross-reference with manifest.tokens
  });
});
```

---

## S2. Data Integrity / Ghost Functions (Python)

Use this for backend logic and "Ghost Function" avoidance.

```python
# test/harness/integrity_harness.py
import os
import re

# Keywords to skip (Resilience Rule)
SKIP_KEYWORDS = {"if", "alert", "console", "eval", "window", "prompt", "confirm"}

def sanitize(text):
    """Artifact Sanitization Mandate: Redact PII and Secrets"""
    text = re.sub(r'[\w\.-]+@[\w\.-]+\.\w+', '[PII-REDACTED]', text)
    text = re.sub(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*', 'Bearer [REDACTED]', text)
    return text

def verify_manifest(manifest_path):
    with open(manifest_path, 'r') as f:
        # Load and loop through manifest (Hard Enforcement)
        pass

if __name__ == "__main__":
    # Entry point for harness execution
    pass
```

---

## S3. API Fault Injection (Mock Service Worker)

```javascript
// test/harness/fault_injection.js
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/external/*', () => {
    // Blueprint B5: Negative Mocking
    return HttpResponse.json(
      { error: "Rate limit exceeded" },
      { status: 429 }
    );
  }),
];

const server = setupServer(...handlers);
server.listen();
```

---

## S4. Visual Regression & Accessibility (Playwright)

Use this to catch unintended visual drift and a11y violations.

```javascript
// tests/harness/visual_a11y.spec.js
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('Visual & A11y Integrity', () => {
  test('Dashboard should match visual baseline and pass a11y', async ({ page }) => {
    await page.goto(process.env.TARGET_URL || 'http://localhost:3000/dashboard');
    
    // 1. Visual Regression (Snapshotting)
    // First run creates baseline, subsequent runs diff against it.
    await expect(page).toHaveScreenshot('dashboard-baseline.png', {
      fullPage: true,
      maxDiffPixels: 100 // Allow minor antialiasing noise
    });

    // 2. Automated Accessibility Gate
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
    expect(accessibilityScanResults.violations).toEqual([]);
  });
});
```

---

## S5. Environmental Determinism (Playwright)

Use this to test time-based logic and network degradation.

```javascript
// tests/harness/environmental_determinism.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Environmental Chaos & Time Travel', () => {
  test('Time-based logic (Overdue tasks)', async ({ page }) => {
    // Freeze time to a specific deterministic date
    const mockNow = new Date('2026-05-11T12:00:00Z').valueOf();
    await page.clock.install({ time: mockNow });
    
    await page.goto('/tasks');
    // Assert logic that depends on "today" or "tomorrow"
  });

  test('Offline Mutation Queue', async ({ page, context }) => {
    await page.goto('/app');
    
    // Simulate dropping the network connection
    await context.setOffline(true);
    
    // Perform mutation, assert it enters offline queue gracefully
    await page.click('#add-task');
    await expect(page.locator('.offline-sync-indicator')).toBeVisible();
  });
});
```

---

## S6. Recursive Improvement Loop (Bash Harness)

Autonomous "Wiggum" or "OCLoop" driver. Continually executes an agent until completion criteria are met.

```bash
#!/bin/bash
# test/harness/loop.sh
# The harness script that manages iterations and git commits for the AI agent.

MAX_ITERATIONS=10
ITERATION=0
SUCCESS_MARKER="DONE"

echo "Starting autonomous improvement loop..."

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION+1))
  echo "--- Iteration \$ITERATION ---"

  # Run the agent against the PRD/PLAN and the test harness
  # e.g., using a CLI tool:
  OUTPUT=\$(agent-cli run --prompt-file PLAN.md --execute test/harness/integrity_harness.py 2>&1)
  
  if echo "\$OUTPUT" | grep -q "\$SUCCESS_MARKER"; then
    echo "Goal achieved: \$SUCCESS_MARKER detected."
    # Commit the final successful state
    git add .
    git commit -m "chore(auto): complete recursive improvement loop"
    exit 0
  fi

  # Rollback on test failure to maintain determinism
  if echo "\$OUTPUT" | grep -q "TEST_FAILED"; then
    echo "Tests failed. Reverting changes..."
    git reset --hard HEAD
    git clean -fd
  else
    # Save partial progress
    git add .
    git commit -m "chore(auto): partial progress iteration \$ITERATION"
  fi
done

echo "Max iterations reached without success."
exit 1
```

---

## S7. Self-Improving Agent Memory (PLAN.md)

Provide this structured document to a recursive loop agent. It serves as the persistent memory bank (`AGENTS.md` or `PLAN.md`) across multiple harness iterations, preventing the agent from spiraling.

```markdown
# Autonomous Execution Plan

## Goal
[Define the specific metric or problem: e.g., "Reduce API errors by 10x" or "Implement Phase 2 of feature X"]

## Definition of Done
The loop exits when the following command returns exit code 0 AND the output contains the word 'DONE':
`npm run bench:api`

## Tasks
- [ ] Task 1: Analyze baseline and generate hypothesis.
- [ ] Task 2: Implement isolated changes.
- [ ] Task 3: Execute `npm run bench:api`.

## Learnings (Persistent Memory)
*(The agent appends discoveries here to avoid repeating mistakes)*
- Iteration 1: Attempted changing `O(n^2)` loop, but broke `test_edge_case`. Reverted.
- Iteration 2:
```

---

## S8. Native Agent Loop Instructions (LOOP_INSTRUCTIONS.md)

Native loop context (e.g. for `CLAUDE.md`). Enforces recursive improvement rules directly via LLM instructions, bypassing external bash scripts.

```markdown
# Recursive Improvement Loop Protocol

You are operating in an autonomous recursive improvement loop. Your goal is to iteratively modify the codebase, verify against a harness, and course-correct until the Definition of Done is met.

## The Goal
[Insert Goal: e.g., "Reduce memory allocation in `src/parser.ts` by 50%"]

## The Harness
[Insert Command: e.g., `npm run bench:parser`]

## Operational Directives
1. **Hypothesize**: Formulate a single, focused change. Do not perform unrelated refactoring.
2. **Execute**: Modify the code using your available tools.
3. **Verify**: Run the Harness. You MUST read the results.
4. **Evaluate**: 
   - If tests pass AND the metric improves -> Commit the change (`git add . && git commit -m "chore(loop): incremental improvement"`).
   - If tests fail OR the metric degrades -> You MUST revert your changes (`git reset --hard HEAD && git clean -fd`) before trying again.
5. **Record**: Log your hypothesis and result in `PLAN.md` to avoid repeating mistakes.

## The Rule of Three (Strategic Backtrack)
If you attempt to fix a failing implementation or hit a performance goal more than **3 times** without success:
1. STOP optimizing the current path.
2. Re-evaluate your assumptions.
3. Pivot to an entirely different architectural approach.

## Termination Criteria
You will stop looping and summarize your results when:
1. The Goal is fully met.
2. You have executed 5 distinct hypotheses without success.
3. You identify a "Hard Ceiling" (e.g., framework limitation) that makes the goal impossible without a rewrite.
```
