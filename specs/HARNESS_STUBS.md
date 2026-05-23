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
