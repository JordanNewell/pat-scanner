# Security Policy

## Reporting a Vulnerability

PAT Scanner is itself a security tool. We take bugs seriously, especially:

- **False negatives** — a credential shape that should match a pattern but doesn't
- **Bypasses** — ways to defeat the scanner without using the documented `BYPASS_SECRET_SCAN` keyword
- **Audit log integrity** — tampering or truncation of `~/.pat-scanner/audit.log`
- **Pattern injection** — input that crashes `grep -E` or causes regex catastrophic backtracking

**Report privately:** open a private security advisory at
https://github.com/JordanNewell/pat-scanner/security/advisories/new

Or email: security@jordannewell.com (PGP key at https://jordannewell.com/pgp.asc)

Do NOT open a public issue for security-sensitive bugs.

## Response timeline

- **Acknowledgement:** within 48 hours
- **Initial assessment:** within 1 week
- **Fix or mitigation:** within 30 days (severity-dependent)
- **Coordinated disclosure:** fix ships first, public disclosure after users have had time to patch

## Scope

**In scope:**
- The scanner script (`hooks/scan-secrets.sh`)
- Default patterns (`patterns/secret-patterns.local`)
- Plugin path resolution and fail-open behavior
- Audit log handling

**Out of scope:**
- Use of the documented `BYPASS_SECRET_SCAN` keyword to deliberately paste credentials (that's user action, not a bug)
- Pattern coverage for services NOT in the default 13 — file a feature request instead
- Leaks that occurred before PAT Scanner was installed (we can't retroactively block)

## Pattern quality reports

If you find a credential shape that should be detected but isn't:

1. Verify against the latest `patterns/secret-patterns.local` (your user override may be stale)
2. Smoke-test the regex: `echo "<sample>" | grep -E "<pattern>"` — must exit 0
3. If the regex needs tightening or adding, open a regular (non-security) issue with:
   - The pattern class (vendor name)
   - The proposed regex
   - At least one clearly-fake test fixture (use the `repeat` helper from `tests/test-scan-secrets.sh` — do NOT paste real credentials)

## Disclosure credit

We credit researchers in release notes unless they prefer otherwise.
