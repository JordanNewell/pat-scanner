#!/usr/bin/env bash
# PAT Scanner — UserPromptSubmit hook that blocks credential-shaped strings
# before they enter the chat transcript.
#
# Usage: scan-secrets.sh
#   stdin: JSON from Claude Code UserPromptSubmit hook
#   exit 0: pass (no match, or bypass keyword present, or patterns file missing — fail-open)
#   exit 2: BLOCK (matched pattern, stderr names the pattern type)
#
# Patterns source resolution (first hit wins):
#   1. $PAT_SCANNER_PATTERNS env var (explicit override)
#   2. ~/.config/secret-patterns.local (user customizations, preserved across plugin updates)
#   3. ${CLAUDE_PLUGIN_ROOT}/patterns/secret-patterns.local (plugin defaults)
#
# Audit log: ~/.pat-scanner/audit.log (blocks only — timestamp, pattern name, session ID)

set -u

BYPASS_KEYWORD="BYPASS_SECRET_SCAN"

# Resolve plugin root (set by Claude Code when invoking plugin hooks)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Patterns file resolution
USER_PATTERNS="$HOME/.config/secret-patterns.local"
DEFAULT_PATTERNS="$PLUGIN_ROOT/patterns/secret-patterns.local"
PATTERNS_FILE="${PAT_SCANNER_PATTERNS:-}"
if [ -z "$PATTERNS_FILE" ]; then
  if [ -f "$USER_PATTERNS" ]; then
    PATTERNS_FILE="$USER_PATTERNS"
  elif [ -f "$DEFAULT_PATTERNS" ]; then
    PATTERNS_FILE="$DEFAULT_PATTERNS"
  fi
fi

# Audit log path
AUDIT_LOG="${PAT_SCANNER_AUDIT_LOG:-$HOME/.pat-scanner/audit.log}"
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null

# Read JSON from stdin
input=$(cat)
# CC sends `prompt` field (verified at https://code.claude.com/docs/en/hooks).
# Fallback chain defends against future field-name changes.
prompt_text=$(echo "$input" | jq -r '.prompt // .prompt_text // .message // .text // .content // empty' 2>/dev/null)

# Empty prompt (shouldn't happen but guard)
if [ -z "$prompt_text" ]; then
  exit 0
fi

# Bypass keyword — explicit opt-out for legitimate debug sessions
if echo "$prompt_text" | grep -qF "$BYPASS_KEYWORD"; then
  exit 0
fi

# Patterns file missing — fail open (warn but don't block)
if [ -z "$PATTERNS_FILE" ] || [ ! -f "$PATTERNS_FILE" ]; then
  echo "WARN: no patterns file found (looked for: \$PAT_SCANNER_PATTERNS, $USER_PATTERNS, $DEFAULT_PATTERNS)" >&2
  exit 0
fi

# Loop patterns, find first match
# Skip comments (#) and blank lines
while IFS= read -r line; do
  # Strip trailing comments
  pattern="${line%%#*}"
  # Trim leading/trailing whitespace
  pattern="${pattern#"${pattern%%[![:space:]]*}"}"
  pattern="${pattern%"${pattern##*[![:space:]]}"}"
  [ -z "$pattern" ] && continue

  if echo "$prompt_text" | grep -qE "$pattern"; then
    # Extract the human-readable name from the original line's trailing comment
    name=$(echo "$line" | grep -oE "#\s*[A-Za-z].*$" | sed 's/^#\s*//')
    [ -z "$name" ] && name="unnamed pattern"
    echo "BLOCKED: prompt contains secret-shaped string matching: $name" >&2
    echo "To bypass for legitimate debug: include literal string '$BYPASS_KEYWORD' in your prompt." >&2
    # Audit log — blocks only
    session_id=$(echo "$input" | jq -r '.session_id // "?"' 2>/dev/null)
    echo "$(date '+%Y-%m-%d %H:%M:%S') BLOCKED name=$name session=$session_id" >> "$AUDIT_LOG" 2>/dev/null
    exit 2
  fi
done < "$PATTERNS_FILE"

exit 0
