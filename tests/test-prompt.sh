#!/bin/sh
# Contract tests for `determinagents prompt` (POSIX sh — runs under dash).
# Usage: sh tests/test-prompt.sh [path/to/bin/determinagents]
set -eu

BIN="${1:-./bin/determinagents}"
export DETERMINAGENTS_HOME
DETERMINAGENTS_HOME="$(cd "$(dirname "$BIN")/.." && pwd)"

FAILED=0
pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

# --list surfaces the headline behaviors
for t in complete resolve next security testing stub; do
  if "$BIN" prompt --list 2>/dev/null | grep -qx "$t"; then
    pass "list contains $t"
  else
    fail "list contains $t"
  fi
done

# complete emits the loop doc plus its protocol binding
OUT="$("$BIN" prompt complete 2>/dev/null)"
case "$OUT" in
  *AUTONOMOUS_COMPLETION_LOOP*) pass "complete names the loop doc" ;;
  *) fail "complete names the loop doc" ;;
esac
case "$OUT" in
  *LOOP_PROTOCOL*) pass "complete binds LOOP_PROTOCOL" ;;
  *) fail "complete binds LOOP_PROTOCOL" ;;
esac

# template behaviors substitute <AUDIT>, never leak the placeholder
OUT="$("$BIN" prompt stub 2>/dev/null)"
case "$OUT" in
  *STUB_AND_COMPLETENESS*) pass "stub substitutes doc name" ;;
  *) fail "stub substitutes doc name" ;;
esac
case "$OUT" in
  *"<AUDIT>"*) fail "stub leaks <AUDIT> placeholder" ;;
  *) pass "stub leaks no <AUDIT> placeholder" ;;
esac

# aliases resolve to the same section (headers differ by invoked token)
if [ "$("$BIN" prompt launch 2>/dev/null | tail -n +7)" = "$("$BIN" prompt launch-readiness 2>/dev/null | tail -n +7)" ]; then
  pass "launch alias matches launch-readiness"
else
  fail "launch alias matches launch-readiness"
fi

# fallback tokens emit an honest pointer, exit 0
for t in adversarial init-loops recursive loop-orchestrator; do
  if "$BIN" prompt "$t" 2>/dev/null | grep -q "audits/"; then
    pass "fallback $t points at its doc"
  else
    fail "fallback $t points at its doc"
  fi
done

# every listed token resolves (exit 0)
# shellcheck disable=SC2046
for t in $("$BIN" prompt --list 2>/dev/null); do
  if "$BIN" prompt "$t" >/dev/null 2>&1; then
    :
  else
    fail "token resolves: $t"
  fi
done
pass "all listed tokens resolve"

# unknown token is a clean error, not a fabricated prompt
if "$BIN" prompt bogus-behavior >/dev/null 2>&1; then
  fail "unknown token exits nonzero"
else
  pass "unknown token exits nonzero"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "all prompt contract tests passed"
else
  echo "one or more prompt contract tests failed"
  exit 1
fi
