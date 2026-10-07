#!/bin/sh
# Contract tests for `determinagents setup` (POSIX sh — runs under dash).
# All installs go under a temp --dir root; the real HOME is never touched.
# Usage: sh tests/test-setup.sh [path/to/bin/determinagents]
#
# shellcheck disable=SC2015
# (test assertions use `check && pass || fail`; pass/fail only echo,
# so the C branch cannot misfire here.)
set -eu

BIN="${1:-./bin/determinagents}"
export DETERMINAGENTS_HOME
DETERMINAGENTS_HOME="$(cd "$(dirname "$BIN")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/det-setup-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT INT TERM

FAILED=0
pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

# claude: skill + hub command, path substituted, markers present
"$BIN" setup claude --dir="$T" >/dev/null 2>&1
[ -f "$T/.claude/skills/determinagents/SKILL.md" ] \
  && pass "claude skill installed" || fail "claude skill installed"
[ -f "$T/.claude/commands/determinagents.md" ] \
  && pass "claude command installed" || fail "claude command installed"
if grep -qF "$DETERMINAGENTS_HOME" "$T/.claude/skills/determinagents/SKILL.md" \
  && ! grep -qF '@LIBRARY_PATH@' "$T/.claude/skills/determinagents/SKILL.md"; then
  pass "claude skill path substituted"
else
  fail "claude skill path substituted"
fi

# idempotent re-run overwrites own files
"$BIN" setup claude --dir="$T" >/dev/null 2>&1 \
  && pass "claude re-setup exits 0" || fail "claude re-setup exits 0"

# foreign files are refused without --force, replaced with it
echo "user content" > "$T/.claude/commands/determinagents.md"
"$BIN" setup claude --dir="$T" >/dev/null 2>&1
[ "$(cat "$T/.claude/commands/determinagents.md")" = "user content" ] \
  && pass "foreign file preserved without --force" \
  || fail "foreign file preserved without --force"
"$BIN" setup claude --dir="$T" --force >/dev/null 2>&1
grep -qF 'generated-by: determinagents setup' "$T/.claude/commands/determinagents.md" \
  && pass "foreign file replaced with --force" \
  || fail "foreign file replaced with --force"

# cursor is project-only
if "$BIN" setup cursor --dir="$T" >/dev/null 2>&1; then
  [ -f "$T/.cursor/rules/determinagents.mdc" ] \
    && pass "cursor rule installed" || fail "cursor rule installed"
else
  fail "cursor setup with --dir"
fi
if "$BIN" setup cursor >/dev/null 2>&1; then
  fail "cursor --global refused"
else
  pass "cursor --global refused"
fi

# gemini: hub + one toml per routing token, live descriptions
"$BIN" setup gemini --dir="$T" >/dev/null 2>&1
[ -f "$T/.gemini/commands/determinagents.toml" ] \
  && pass "gemini hub installed" || fail "gemini hub installed"
N_TOKENS="$("$BIN" prompt --list 2>/dev/null | wc -l | tr -d ' ')"
N_TOML="$(find "$T/.gemini/commands/determinagents" -name '*.toml' | wc -l | tr -d ' ')"
[ "$N_TOML" -ge 30 ] \
  && pass "gemini behavior tomls generated ($N_TOML of $N_TOKENS tokens)" \
  || fail "gemini behavior tomls generated ($N_TOML of $N_TOKENS tokens)"
if grep -q '!{determinagents prompt stub' "$T/.gemini/commands/determinagents/stub.toml" 2>/dev/null; then
  pass "gemini stub toml is a live pointer"
else
  fail "gemini stub toml is a live pointer"
fi

# agy: plugin manifest + agents, valid JSON shape
"$BIN" setup agy --dir="$T" >/dev/null 2>&1
[ -f "$T/.gemini/antigravity-cli/plugins/determinagents/plugin.json" ] \
  && pass "agy plugin.json installed" || fail "agy plugin.json installed"
N_AGENTS="$(find "$T/.gemini/antigravity-cli/plugins/determinagents/agents" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
[ "$N_AGENTS" -ge 30 ] \
  && pass "agy agents generated ($N_AGENTS)" || fail "agy agents generated ($N_AGENTS)"
if grep -q '"name": "determinagents:complete"' \
  "$T/.gemini/antigravity-cli/plugins/determinagents/agents/determinagents-complete.json" 2>/dev/null; then
  pass "agy complete agent namespaced"
else
  fail "agy complete agent namespaced"
fi

# opencode native path
"$BIN" setup opencode --dir="$T" >/dev/null 2>&1
[ -f "$T/.opencode/commands/determinagents.md" ] \
  && pass "opencode command installed" || fail "opencode command installed"

# --remove deletes owned files, keeps foreign ones
echo "user content" > "$T/.opencode/commands/determinagents.md"
"$BIN" setup opencode --dir="$T" --remove >/dev/null 2>&1
[ -f "$T/.opencode/commands/determinagents.md" ] \
  && pass "--remove keeps foreign files" || fail "--remove keeps foreign files"
"$BIN" setup claude --dir="$T" --remove >/dev/null 2>&1
[ ! -e "$T/.claude/skills/determinagents/SKILL.md" ] \
  && pass "--remove deletes owned files" || fail "--remove deletes owned files"

# unknown tool is a clean error
if "$BIN" setup vim >/dev/null 2>&1; then
  fail "unknown tool exits nonzero"
else
  pass "unknown tool exits nonzero"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "all setup contract tests passed"
else
  echo "one or more setup contract tests failed"
  exit 1
fi
