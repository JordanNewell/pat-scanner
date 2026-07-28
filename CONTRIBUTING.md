# Contributing

Thanks for considering a contribution to PAT Scanner. Two areas have the highest leverage:

1. **New patterns** — append a regex + clearly-fake test fixture
2. **POSIX ERE portability** — test on macOS/BSD grep (Linux GNU grep is current target)

## Adding a new credential pattern

### 1. Verify the regex shape

POSIX ERE only (`grep -E`). Three silent-failure traps to avoid:

- **No `(?:...)` non-capturing groups** — use `(...)` capturing groups instead
- **No `\s`/`\d`/`\w`** — use `[[:space:]]`/`[0-9]`/`[A-Za-z0-9_]`
- **No `[[:space:]]` inside bracket expressions** — the inner `]` closes the bracket early. Use separate alternation: `([\`'";]|[[:space:]]|...)` not `[\`'"[[:space:]];]`

### 2. Add the pattern

Append to `patterns/secret-patterns.local`:

```
myorg_[a-z]{8}_[a-f0-9]{32}                                                       # MyOrg internal API key
```

Format: `<regex>` + spaces + `# <name>`. The name shows in stderr when blocked.

### 3. Smoke-test the regex

```bash
echo "myorg_abcdefgh_0123456789abcdef0123456789abcdef" | grep -E "myorg_[a-z]{8}_[a-f0-9]{32}"
# exit 0 = match, exit 1 = no match, exit 2 = regex syntax error
```

### 4. Add a test case

In `tests/test-scan-secrets.sh`, construct a clearly-fake fixture and add a `check_blocks` call:

```bash
# At the top with the other fixtures
MYORG_FAKE="myorg_$(repeat 'ab' 4)_$(repeat '0' 32)"

# In the block cases section
check_blocks "MyOrg API key" \
  "{\"prompt\":\"$MYORG_FAKE\"}" \
  "MyOrg"
```

**Critical:** Use the `repeat` helper to construct fixtures. Do NOT paste real-shaped tokens directly into the file — GitHub's secret scanning will reject the push. Construct from clearly-fake parts: `FAKE`, `0`, `X`, `DEADBEEF`.

### 5. Run tests

```bash
bash tests/test-scan-secrets.sh
```

Must show `Pass: N  Fail: 0`.

### 6. Commit + PR

```bash
git checkout -b add-myorg-pattern
git add patterns/secret-patterns.local tests/test-scan-secrets.sh
git commit -m "add MyOrg API key pattern"
git push -u origin add-myorg-pattern
gh pr create
```

## Development setup

```bash
git clone https://github.com/JordanNewell/pat-scanner.git
cd pat-scanner
bash tests/test-scan-secrets.sh  # must pass on clone
```

Dependencies: `bash`, `jq`, `grep -E` (POSIX ERE). All standard on Linux + macOS. Windows users typically have these via Git Bash.

## Test fixture rules (load-bearing)

Fixtures must be **constructed programmatically** from clearly-fake parts. Static strings in the test file must NOT match real provider patterns. This is what allows the repo to push through GitHub's secret scanning without `.gitleaksignore` brittleness.

Wrong:
```bash
check_blocks "Anthropic key" \
  '{"prompt":"sk-ant-api03-aaaa...AA"}' \
  "Anthropic"
```

Right:
```bash
ANTHROPIC_MIDDLE="$(repeat 'FAKE' 23)X"  # 93 chars
ANTHROPIC_FAKE="sk-ant-api03-${ANTHROPIC_MIDDLE}AA"

check_blocks "Anthropic key" \
  "{\"prompt\":\"$ANTHROPIC_FAKE\"}" \
  "Anthropic"
```

The fixture still exercises the full pattern at test time. The static file shows only `repeat 'FAKE' 23` — no real-shaped tokens visible to scanners.

## Platform notes

- **Linux GNU grep** — primary target, all tests pass
- **macOS BSD grep** — untested. PRs welcome if any patterns need adjustment
- **Windows Git Bash** — works (production environment for the original ship)

## Code style

- Bash scripts: `set -u`, no `set -e` (scanner needs graceful fallback), `#!/usr/bin/env bash`
- Comments only for non-obvious logic (why, not what)
- No emojis in code or commit messages

## Commit message style

- Subject ≤72 chars, imperative mood
- Body wraps at 80, explains "why" when non-obvious
- No `Co-Authored-By: Claude` or AI-attribution trailers (per maintainer convention)
- Conventional commits not required but appreciated: `feat:`, `fix:`, `docs:`, `test:`

## License

By contributing, you agree your contributions are licensed MIT alongside the rest of the project.
