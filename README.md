# PAT Scanner

> Block credential leaks at chat-time. Claude Code `UserPromptSubmit` hook that catches 13 PAT classes before they enter the transcript.

Pre-commit hooks catch leaks at git time. PAT Scanner catches them at chat time — the actual point of leak. Companion defense to `gitleaks`/`trufflehog`, not a replacement.

## Install

```bash
# Add the marketplace (one-time)
/plugin marketplace add JordanNewell/pat-scanner

# Install
/plugin install pat-scanner
```

Or clone and link locally:

```bash
git clone https://github.com/JordanNewell/pat-scanner.git ~/pat-scanner
/plugin marketplace add ~/pat-scanner
/plugin install pat-scanner
```

Restart Claude Code if it doesn't auto-reload. Verify with `/help` → look for the UserPromptSubmit hook.

## What it catches (13 classes out of the box)

| Service | Pattern shape |
|---|---|
| Figma | `figd_<40+ chars>` |
| Anthropic | `sk-ant-api03-<93 chars>AA` |
| OpenAI legacy | `sk-<20>T3BlbkFJ<20>` |
| OpenAI project | `sk-proj-<58>T3BlbkFJ<58>` |
| GitHub classic | `gh[pousr]_<36>` |
| GitHub fine-grained | `github_pat_<82>` |
| Slack | `xox[baprs]-<10+>` |
| Stripe | `(sk|rk|pk)_(test|live|prod)_<10-99>` |
| PyPI | `pypi-AgEIcHlwaS5vcmc<50-1000>` |
| Z.ai / Zhipu | `<32 hex>.<16 alphanum>` |
| JWT (generic) | `eyJ<10+>.<10+>.<10+>` |
| Natural.com | `ak_ntl_prod_<36>` |
| AWS | `AKIA<16 upper alnum>` |

## Customize

Copy the defaults to your user config and edit:

```bash
mkdir -p ~/.config
cp ~/pat-scanner/patterns/secret-patterns.local ~/.config/secret-patterns.local
$EDITOR ~/.config/secret-patterns.local
```

Your user file takes precedence over plugin defaults — survives plugin updates.

### Add a new pattern

One line per pattern, format: `<POSIX ERE regex>  # <name>`

```
myorg_[a-z]{8}_[a-f0-9]{32}                                                       # MyOrg internal API key
```

Smoke-test before relying on it:

```bash
echo "myorg_abcdef_0123456789abcdef0123456789abcdef" | grep -E "myorg_[a-z]{8}_[a-f0-9]{32}"
# exit code 0 = match, exit code 1 = no match, exit code 2 = regex syntax error
```

## Bypass

Include the literal string `BYPASS_SECRET_SCAN` anywhere in your prompt to skip the scan:

```
debugging this token shape: figd_xxx BYPASS_SECRET_SCAN
```

Use sparingly. Reserve for:
- Debugging the scanner itself
- Pasting example tokens that aren't real
- Discussing regex patterns

Never use bypass for real credentials. Write them to `.env` via shell, not chat.

## POSIX ERE gotchas

The patterns file uses POSIX ERE (`grep -E`) — not PCRE. Three silent-failure traps:

1. **No `(?:...)` non-capturing groups.** Use `(...)` capturing groups instead.
2. **No `\s`/`\d`/`\w`.** Use `[[:space:]]`/`[0-9]`/`[A-Za-z0-9_]`.
3. **No `[[:space:]]` inside bracket expressions.** `[\`'"[[:space:]];]` looks right but the inner `]` closes the bracket early. Use separate alternation: `([\`'";]|[[:space:]]|...)`.

If a pattern isn't matching, smoke-test with `echo "<sample>" | grep -E "<pattern>"` BEFORE adding it.

## Audit log

Blocks are logged to `~/.pat-scanner/audit.log`:

```
2026-07-27 19:55:21 BLOCKED name=Figma PAT session=96d067dd-0674-4121-8119-497f7700e4cd
```

Override path with `$PAT_SCANNER_AUDIT_LOG`. Disable by pointing at `/dev/null`.

## Fail-open behavior

If the patterns file is missing or unreadable, the scanner exits 0 with a stderr warning. This prevents a missing file from blocking all of Claude Code.

## Tests

After any change to patterns or scanner:

```bash
bash tests/test-scan-secrets.sh
```

Expected: `Pass: 18  Fail: 0` (or higher if new test cases were added).

Tests use the bundled defaults explicitly (don't depend on user file state).

## Fleet deployment

The hook fires per Claude Code session. For fleet rollouts (multiple CC installs):

1. Install the plugin on each host via `/plugin install pat-scanner`
2. Distribute your org's `~/.config/secret-patterns.local` via your standard config management (Ansible, etc.)
3. Centralize audit logs by setting `PAT_SCANNER_AUDIT_LOG` to a network path or shipping `~/.pat-scanner/audit.log` via your log collector

OpenClaw agents (and other non-CC automation) don't fire `UserPromptSubmit` — they should rely on git-time scanners (`gitleaks`, `trufflehog`) at commit time.

## License

MIT © Jordan Newell

## Roadmap

- **v0.2** — Hosted team tier (centralized audit dashboard, Slack/Teams alerting on block, SOC2 export). Separate product, OSS plugin stays free.
- **v0.3** — Additional pattern classes (GitLab PAT, Bitbucket app password, Linear API key, Datadog, etc.) — contributions welcome.
- **v0.4** — Multi-line paste detection (current scanner is line-oriented).

## Contributing

PRs welcome. Two high-value areas:

1. **New patterns** — append to `patterns/secret-patterns.local` + add test case + verify with `bash tests/test-scan-secrets.sh`
2. **POSIX ERE portability** — test on macOS/BSD grep (Linux GNU grep is current target)

See `SKILL.md` for the full hook architecture and extension guide.


<p align="right">
  <a href="https://jordannewell.com" title="Built by Jordan Newell">
    <img src="assets/newell-badge.png" alt="Built by Jordan Newell" width="48" height="48">
  </a>
</p>