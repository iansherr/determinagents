#!/bin/bash
# Test runner for DeterminAgents audit prompt discovery patterns

set -e

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
echo "=== DeterminAgents Prompt Evaluation Suite ==="
echo "Running static verification on mock fixtures..."

FAILED=0

# Test 1: Structural Entropy Audit patterns on god_file.js
echo "--------------------------------------------------"
echo "Testing STRUCTURAL_ENTROPY patterns on god_file.js..."

GOD_FILE="$FIXTURES_DIR/god_file.js"

# 1.1 State Management (useState)
if grep -q "useState" "$GOD_FILE"; then
  echo "  [PASS] Found State Management signal (useState)"
else
  echo "  [FAIL] Missing State Management signal"
  FAILED=1
fi

# 1.2 Side effects / IO (localStorage, axios)
if grep -qE "(localStorage|axios\.get)" "$GOD_FILE"; then
  echo "  [PASS] Found Side effects / I/O signal (localStorage/axios)"
else
  echo "  [FAIL] Missing Side effects / I/O signal"
  FAILED=1
fi

# 1.3 Data shaping (normalization functions)
if grep -q "normalizeWorkspace" "$GOD_FILE"; then
  echo "  [PASS] Found Data Shaping signal (normalizeWorkspace)"
else
  echo "  [FAIL] Missing Data Shaping signal"
  FAILED=1
fi

# 1.4 UI rendering (JSX return)
if grep -q "return (" "$GOD_FILE"; then
  echo "  [PASS] Found UI rendering signal (JSX return)"
else
  echo "  [FAIL] Missing UI rendering signal"
  FAILED=1
fi


# Test 2: Regression Surface Audit patterns on auth_regression.js
echo "--------------------------------------------------"
echo "Testing REGRESSION_SURFACE patterns on auth_regression.js..."

REG_FILE="$FIXTURES_DIR/auth_regression.js"

# 2.1 Fallback ladders (||)
if grep -qE '\|\|' "$REG_FILE"; then
  echo "  [PASS] Found fallback ladder pattern (||)"
else
  echo "  [FAIL] Missing fallback ladder pattern"
  FAILED=1
fi

# 2.2 Duplicate local storage aliases
if grep -q "fleetcrewSessionId" "$REG_FILE" && grep -q "sessionId" "$REG_FILE"; then
  echo "  [PASS] Found duplicate storage credential aliases"
else
  echo "  [FAIL] Missing duplicate storage credential aliases"
  FAILED=1
fi

# 2.3 Broad catch with aggressive side-effects (catch -> removeItem/location)
# Simulate the command in Phase 4 of REGRESSION_SURFACE.md
catch_side_effects=$(grep -rnA 5 -E '\bcatch\b' "$REG_FILE" | grep -iE 'removeItem|location' || true)
if [ -n "$catch_side_effects" ]; then
  echo "  [PASS] Found broad catch block with aggressive side-effects"
else
  echo "  [FAIL] Missing broad catch block with aggressive side-effects"
  FAILED=1
fi

echo "--------------------------------------------------"
if [ $FAILED -eq 0 ]; then
  echo "RESULT: ALL TESTS PASSED SUCCESSFULLY!"
  exit 0
else
  echo "RESULT: SOME TESTS FAILED!"
  exit 1
fi
