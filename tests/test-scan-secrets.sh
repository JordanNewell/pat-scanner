#!/usr/bin/env bash
# Test harness for scan-secrets.sh
# Run: bash tests/test-scan-secrets.sh
#
# Fixtures are constructed programmatically from clearly-fake parts (FAKE, X, 0, DEADBEEF).
# This keeps the static file free of real-shaped tokens that would trip GitHub secret scanning
# and provider-side token verifiers, while still exercising every pattern end-to-end.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/hooks/scan-secrets.sh"
DEFAULT_PATTERNS="$(cd "$(dirname "$0")/.." && pwd)/patterns/secret-patterns.local"

PASS=0
FAIL=0

check_blocks() {
  local name="$1" input="$2" expected_pattern="$3"
  local stderr_out exit_code
  stderr_out=$(echo "$input" | "$SCRIPT" 2>&1 >/dev/null)
  exit_code=$?
  if [ "$exit_code" -eq 2 ] && echo "$stderr_out" | grep -qE "$expected_pattern"; then
    PASS=$((PASS+1)); echo "  ✓ $name"
  else
    FAIL=$((FAIL+1)); echo "  ✗ $name (exit=$exit_code stderr=$stderr_out)"
  fi
}

check_passes() {
  local name="$1" input="$2"
  echo "$input" | "$SCRIPT" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    PASS=$((PASS+1)); echo "  ✓ $name"
  else
    FAIL=$((FAIL+1)); echo "  ✗ $name (should pass)"
  fi
}

# === Construct fake fixtures at test time ===
# Build from clearly-fake parts so the static file has no real-shaped tokens.
repeat() { printf "$1%.0s" $(seq 1 "$2"); }

FIGMA_FAKE="figd_$(repeat 'FAKE' 13)"                              # 52 chars after figd_
ANTHROPIC_MIDDLE="$(repeat 'FAKE' 23)X"                            # 93 chars
ANTHROPIC_FAKE="sk-ant-api03-${ANTHROPIC_MIDDLE}AA"
OPENAI_PREFIX="$(repeat 'X' 20)"                                   # 20 chars before T3BlbkFJ marker
OPENAI_SUFFIX="$(repeat 'X' 20)"                                   # 20 chars after
OPENAI_FAKE="sk-${OPENAI_PREFIX}T3BlbkFJ${OPENAI_SUFFIX}"
GITHUB_FAKE="ghp_$(repeat '0' 36)"                                 # 36 chars (all zeros — never valid)
SLACK_FAKE="xoxb-$(repeat '0' 12)-$(repeat '0' 12)"                 # all zeros — never a real Slack token
STRIPE_FAKE="sk_test_$(repeat 'FAKE' 5)"                           # sk_test_ is Stripe's documented test prefix
PYPI_FAKE="pypi-AgEIcHlwaS5vcmc$(repeat 'FAKE' 14)"                # 56 chars after pypi-
ZAI_FAKE="$(repeat '0' 32).$(repeat '0' 16)"                       # 32hex.16alphanum (all zeros)
NATURAL_FAKE="ak_ntl_prod_$(repeat '0' 36)"                        # 36 chars (all zeros)
AWS_FAKE="AKIA$(repeat 'A' 16)"                                    # AWS's documented example shape

# Use the bundled defaults explicitly (overrides any user file)
export PAT_SCANNER_PATTERNS="$DEFAULT_PATTERNS"
# Audit log to a throwaway path so tests don't pollute real audit
export PAT_SCANNER_AUDIT_LOG="/tmp/pat-scanner-test-audit.log"

# === Pass-through cases ===
check_passes "normal text" \
  '{"prompt":"hello world"}'

# === Block cases — one per leaked class ===
check_blocks "Figma PAT" \
  "{\"prompt\":\"$FIGMA_FAKE\"}" \
  "Figma"

check_blocks "Anthropic key (end of string)" \
  "{\"prompt\":\"$ANTHROPIC_FAKE\"}" \
  "Anthropic"

check_blocks "Anthropic key embedded mid-sentence" \
  "{\"prompt\":\"here is the key $ANTHROPIC_FAKE followed by more text\"}" \
  "Anthropic"

check_blocks "OpenAI legacy" \
  "{\"prompt\":\"$OPENAI_FAKE\"}" \
  "OpenAI"

check_blocks "GitHub classic PAT" \
  "{\"prompt\":\"$GITHUB_FAKE\"}" \
  "GitHub"

check_blocks "Slack bot token" \
  "{\"prompt\":\"xoxb-000000000000-000000000000\"}" \
  "Slack"

check_blocks "Stripe test key" \
  "{\"prompt\":\"$STRIPE_FAKE\"}" \
  "Stripe"

check_blocks "PyPI token" \
  "{\"prompt\":\"$PYPI_FAKE\"}" \
  "PyPI"

check_blocks "Z.ai API key" \
  "{\"prompt\":\"$ZAI_FAKE\"}" \
  "Z.ai"

check_blocks "Natural key (unverified shape)" \
  "{\"prompt\":\"$NATURAL_FAKE\"}" \
  "Natural"

check_blocks "AWS access key" \
  "{\"prompt\":\"$AWS_FAKE\"}" \
  "AWS"

# === Pass-through edge cases ===
check_passes "JWT fragment too short to match" \
  '{"prompt":"example with ref to eyJ.example but truncated"}'

check_passes "false-positive bait (short hex)" \
  '{"prompt":"commit sha abc123 def456 not a key"}'

check_passes "discussion of patterns" \
  '{"prompt":"the figd_ prefix is what Figma PATs use"}'

check_passes "code example with placeholder (under 40 chars)" \
  '{"prompt":"FIGMA_PAT=figd_PLACEHOLDER_USE_REAL_TOKEN"}'

# === Bypass keyword ===
check_passes "bypass keyword present" \
  '{"prompt":"figd_test BYPASS_SECRET_SCAN debugging"}'

# === Patterns file resolution ===
# Verify fail-open when patterns file is missing
PAT_SCANNER_PATTERNS="/nonexistent" echo '{"prompt":"figd_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}' | PAT_SCANNER_PATTERNS="/nonexistent" "$SCRIPT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  PASS=$((PASS+1)); echo "  ✓ missing patterns file fails open"
else
  FAIL=$((FAIL+1)); echo "  ✗ missing patterns file should fail open"
fi

echo
echo "Pass: $PASS  Fail: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
