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

DIFF_CONTENT=$(cat "$DIFF_FILE")

# --- Call Anthropic API ---
echo "Running code review via Anthropic API..."

REVIEW_PROMPT="You are a code reviewer. Review the following git diff for a pull request.

Check for:
- Security issues (hardcoded secrets, injection vulnerabilities, unsafe operations)
- Logic errors or bugs
- Code quality issues (clarity, maintainability, duplication)
- Missing error handling
- Test coverage gaps

For each issue found, use this format:
**[SEVERITY: BLOCKER|HIGH|MEDIUM|LOW]** \`path/to/file:line\` — Description

At the end provide:
- **Summary:** 1-2 sentence overall assessment
- **Verdict:** APPROVED | CHANGES NEEDED | BLOCKED

--- PR DIFF ---
${DIFF_CONTENT}"

# Build JSON payload using python3 (handles escaping reliably)
python3 - <<PYEOF
import json, sys

prompt = """${REVIEW_PROMPT}"""

payload = {
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": prompt}]
}

with open("${PAYLOAD_FILE}", "w") as f:
    json.dump(payload, f)
PYEOF

RESPONSE=$(curl -sf https://api.anthropic.com/v1/messages \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d @"${PAYLOAD_FILE}" 2>/dev/null) || {
  echo "⚠ Anthropic API call failed — skipping review"
  rm -f "$DIFF_FILE" "$PAYLOAD_FILE"
  exit 0
}

# Extract text from response
python3 - <<PYEOF
import json, sys

response = json.loads("""${RESPONSE}""")
text = response.get("content", [{}])[0].get("text", "⚠ No review content returned")

with open("${REVIEW_FILE}", "w") as f:
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
    rm -f "$REVIEW_FILE" "$DIFF_FILE" "$PAYLOAD_FILE"
    exit 1
  fi
fi

rm -f "$REVIEW_FILE" "$DIFF_FILE" "$PAYLOAD_FILE"
echo "=== Code review complete ==="
exit 0
