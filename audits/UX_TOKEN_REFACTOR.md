# UX Token Refactor

## Purpose

Autonomously refactor hardcoded visual values (colors, spacing, radii) into Design System tokens. This is a "Cleanup Loop" that ensures the implementation matches the `DESIGN.md` specification and remains themeable.

## Mode: Mutating

**Protocol**: This audit follows the [Recursive Self-Improvement Protocol](../specs/LOOP_PROTOCOL.md).

This agent **mutates** CSS and component files. It requires a disposable workspace.

## When to run

- After a major UI development phase.
- When `UX_DESIGN_AUDIT` identifies a high density of hardcoded values.
- To migrate a legacy UI to a new design system.

## Flags

- `--tokens="<path/to/design_system.css>"`: The source of truth for token names (e.g., `app/style.css`).
- `--guard="<command>"`: The shell command to run the "Token Guard" verification (e.g., `node scripts/loop_ux_token_guard.js`).

## Output

1. **Refactored Code**: Files where hardcoded literals have been replaced with `var(--token)`.
2. **Refactor Report**: `docs/reports/UX_TOKEN_REFACTOR_<YYYY-MM-DD>.md`.

---

## Phase 1: Token Mapping

Read the `--tokens` file and create a mapping of literal values to token names.
- Example: `#7B6CD9` -> `var(--violet-500)`.
- Example: `8px` -> `var(--space-2)`.

## Phase 2: Iterative Refactor

Run the `--guard` command to find violations.
For each violation:
1. Identify the hardcoded literal and its context.
2. Find the closest match in the token mapping.
3. Replace the literal with the token.
4. Verify via the `--guard` command.
5. If visual regression testing is available, verify that the UI still "looks" the same.

## Phase 3: Validation

- Run the full project test suite (`npm test`).
- Run the `--guard` one last time to ensure 100% compliance.
