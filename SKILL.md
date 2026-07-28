---
name: pat-scanner
description: Blocks credential-shaped strings (Figma, Anthropic, OpenAI, GitHub, Slack, Stripe, PyPI, Z.ai, JWT, Natural, AWS) from entering the chat transcript. Use when adding new patterns, debugging bypass behavior, or extending detection coverage.
---

# PAT Scanner

UserPromptSubmit hook that scans prompt text for credential patterns and blocks them at chat-time (before they reach the transcript). Ships with 13 high-confidence regex patterns; users can override or extend via `~/.config/secret-patterns.local`.

## When this skill applies

- Adding a new credential pattern (e.g., your org's internal API key shape)
- Debugging why a paste did or didn't block
- Extending detection coverage to a new service
- Explaining the bypass keyword to a teammate

## How it works

1. Claude Code fires the `UserPromptSubmit` event on every prompt submission.
2. The hook script `hooks/scan-secrets.sh` reads JSON from stdin.
3. Extracts `.prompt` field via `jq` (with fallback chain for forward-compat).
4. Checks for `BYPASS_SECRET_SCAN` keyword → exit 0 if present.
5. Loops regex patterns from the resolved patterns file.
6. First match → writes audit log entry, exits 2 (Claude Code blocks the prompt).
7. No match → exit 0 (prompt proceeds normally).

## Pattern file resolution (first hit wins)

1. `$PAT_SCANNER_PATTERNS` (explicit env var override)
2. `~/.config/secret-patterns.local` (user customizations, survives plugin updates)
3. `${CLAUDE_PLUGIN_ROOT}/patterns/secret-patterns.local` (plugin defaults)

## Adding a new pattern

1. Create or edit `~/.config/secret-patterns.local`.
2. Append one line per pattern, format: `<POSIX ERE regex>  # <name for stderr message>`
3. Smoke-test: `echo "<sample token>" | grep -E "<pattern>"` — must exit 0.
4. Add a test case to `tests/test-scan-secrets.sh`.
5. Run: `bash tests/test-scan-secrets.sh` — must show `Pass: N  Fail: 0`.

## POSIX ERE gotchas

`grep -E` is POSIX ERE, not PCRE. Three silent-failure traps:

1. **No `(?:...)` non-capturing groups.** Use `(...)` capturing groups.
2. **No `\s`/`\d`/`\w`.** Use `[[:space:]]`/`[0-9]`/`[A-Za-z0-9_]`.
3. **No `[[:space:]]` inside bracket expressions.** The inner `]` closes the bracket early. Use separate alternation: `([\`'";]|[[:space:]]|...)` not `[\`'"[[:space:]];]`.

## Bypass keyword

Include the literal string `BYPASS_SECRET_SCAN` anywhere in your prompt to skip the scan. Use sparingly:
- Debugging the scanner itself
- Pasting example tokens that aren't real
- Discussing regex patterns

Never use bypass for real credentials. Write them to `.env` via shell, not chat.

## Audit log

Blocks are logged to `~/.pat-scanner/audit.log`:
```
2026-07-27 19:55:21 BLOCKED name=Figma PAT session=96d067dd-0674-4121-8119-497f7700e4cd
```

Override the path with `$PAT_SCANNER_AUDIT_LOG`.

## Fail-open behavior

If the patterns file is missing or unreadable, the scanner exits 0 (passes through) with a stderr warning. This prevents a missing file from blocking all of Claude Code.

## Related

- Source: https://github.com/JordanNewell/pat-scanner
- Author: Jordan Newell (https://jordannewell.com)
