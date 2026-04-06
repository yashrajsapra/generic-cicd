#!/usr/bin/env bash
# Code review stage: fetches PR diff and calls Anthropic API for review,
# then posts the review as a PR comment.
#
# Required env vars:
#   PR_NUMBER         — PR number to review
#   ANTHROPIC_API_KEY — Anthropic API key (skip review if unset)
#   GH_TOKEN          — GitHub token for gh CLI (auto-set by Actions)
#
# Optional env vars:
#   BLOCKING          — if "true", exit 1 when review flags BLOCKER/HIGH issues
#   MAX_DIFF_CHARS    — max diff size in chars before truncation (default: 8000)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAX_DIFF_CHARS="${MAX_DIFF_CHARS:-8000}"
BLOCKING="${BLOCKING:-false}"
REVIEW_FILE="/tmp/cicd-review-$$.md"
DIFF_FILE="/tmp/cicd-diff-$$.patch"
PAYLOAD_FILE="/tmp/cicd-payload-$$.json"

# --- Guard: skip if no API key ---
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "⚠ ANTHROPIC_API_KEY not set — skipping code review stage"
  exit 0
fi

# --- Guard: skip if no PR number ---
if [ -z "${PR_NUMBER:-}" ]; then
  echo "⚠ PR_NUMBER not set — skipping code review stage"
  exit 0
fi

echo "=== Code Review (PR #${PR_NUMBER}) ==="

# --- Fetch PR diff ---
echo "Fetching PR diff..."
"$SCRIPT_DIR/pr-diff.sh" > "$DIFF_FILE" 2>/dev/null || {
  echo "⚠ Could not fetch PR diff — skipping review"
  exit 0
}

DIFF_SIZE=$(wc -c < "$DIFF_FILE")
echo "Diff size: ${DIFF_SIZE} chars"

# Truncate if too large
if [ "$DIFF_SIZE" -gt "$MAX_DIFF_CHARS" ]; then
  echo "⚠ Diff exceeds ${MAX_DIFF_CHARS} chars — truncating"
  {
    head -c "$MAX_DIFF_CHARS" "$DIFF_FILE"
    echo -e "\n\n[... diff truncated at ${MAX_DIFF_CHARS} chars ...]"
  } > "${DIFF_FILE}.tmp"
  mv "${DIFF_FILE}.tmp" "$DIFF_FILE"
fi

# --- Call Anthropic API ---
echo "Running code review via Anthropic API..."

RESPONSE_FILE="/tmp/cicd-response-$$.json"

# Build JSON payload — Python reads diff from file (avoids shell-escaping the diff into Python source)
python3 - "$DIFF_FILE" "$PAYLOAD_FILE" <<'PYEOF'
import json, sys

diff_file, payload_file = sys.argv[1], sys.argv[2]

with open(diff_file, "r", errors="replace") as f:
    diff_content = f.read()

prompt = (
    "You are a code reviewer. Review the following git diff for a pull request.\n\n"
    "Check for:\n"
    "- Security issues (hardcoded secrets, injection vulnerabilities, unsafe operations)\n"
    "- Logic errors or bugs\n"
    "- Code quality issues (clarity, maintainability, duplication)\n"
    "- Missing error handling\n"
    "- Test coverage gaps\n\n"
    "For each issue found, use this format:\n"
    "**[SEVERITY: BLOCKER|HIGH|MEDIUM|LOW]** `path/to/file:line` — Description\n\n"
    "At the end provide:\n"
    "- **Summary:** 1-2 sentence overall assessment\n"
    "- **Verdict:** APPROVED | CHANGES NEEDED | BLOCKED\n\n"
    "--- PR DIFF ---\n"
    + diff_content
)

payload = {
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": prompt}]
}

with open(payload_file, "w") as f:
    json.dump(payload, f)
PYEOF

HTTP_CODE=$(curl -s -w "%{http_code}" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d @"${PAYLOAD_FILE}" \
  -o "$RESPONSE_FILE" \
  "https://api.anthropic.com/v1/messages" 2>/dev/null) || HTTP_CODE="000"

if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ] 2>/dev/null; then
  echo "⚠ Anthropic API returned HTTP ${HTTP_CODE} — skipping review"
  # Log error body (may contain useful info; API key not in response)
  cat "$RESPONSE_FILE" 2>/dev/null | head -5 || true
  rm -f "$DIFF_FILE" "$PAYLOAD_FILE" "$RESPONSE_FILE"
  exit 0
fi

# Extract text from response — Python reads from file (avoids embedding JSON in Python source)
python3 - "$RESPONSE_FILE" "$REVIEW_FILE" <<'PYEOF'
import json, sys

response_file, review_file = sys.argv[1], sys.argv[2]

with open(response_file, "r") as f:
    response = json.load(f)

# Check for API error response
if "error" in response:
    text = f"⚠ API error: {response['error'].get('message', 'unknown error')}"
else:
    text = response.get("content", [{}])[0].get("text", "⚠ No review content returned")

with open(review_file, "w") as f:
    f.write("## Automated Code Review\n\n")
    f.write(text)
PYEOF

echo "Review generated ($(wc -c < "$REVIEW_FILE") chars)"

# --- Post review as PR comment ---
echo "Posting review as PR comment..."
"$SCRIPT_DIR/pr-comment.sh" "$REVIEW_FILE" && echo "✓ Review posted" || echo "⚠ Failed to post review comment"

# --- Blocking mode ---
if [ "$BLOCKING" = "true" ]; then
  if grep -qE "\[SEVERITY: (BLOCKER|HIGH)\]" "$REVIEW_FILE" 2>/dev/null; then
    echo "✗ Blocking issues found in review — failing build"
    cat "$REVIEW_FILE"
    rm -f "$REVIEW_FILE" "$DIFF_FILE" "$PAYLOAD_FILE" "$RESPONSE_FILE"
    exit 1
  fi
fi

rm -f "$REVIEW_FILE" "$DIFF_FILE" "$PAYLOAD_FILE" "$RESPONSE_FILE"
echo "=== Code review complete ==="
exit 0
