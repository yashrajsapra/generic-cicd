#!/usr/bin/env bash
# Code review stage: fetches PR diff and runs claude -p --skill gstack-review,
# then posts the review as a PR comment.
#
# Required env vars:
#   PR_NUMBER         — PR number to review
#   ANTHROPIC_API_KEY — Anthropic API key (skip review if unset)
#
# Optional env vars:
#   BLOCKING          — if "true", exit 1 when review flags BLOCKER/HIGH issues
#   MAX_DIFF_CHARS    — max diff size in chars before truncation (default: 8000)
#   CICD_CONFIG_PATH  — path to .cicd/config.yml (default: .cicd/config.yml)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAX_DIFF_CHARS="${MAX_DIFF_CHARS:-8000}"
BLOCKING="${BLOCKING:-false}"
REVIEW_FILE="/tmp/cicd-review-$$.md"
DIFF_FILE="/tmp/cicd-diff-$$.patch"

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
  head -c "$MAX_DIFF_CHARS" "$DIFF_FILE" > "${DIFF_FILE}.tmp"
  echo -e "\n\n[... diff truncated at ${MAX_DIFF_CHARS} chars — review may be incomplete ...]" >> "${DIFF_FILE}.tmp"
  mv "${DIFF_FILE}.tmp" "$DIFF_FILE"
fi

# --- Run claude code review ---
echo "Running code review..."
REVIEW_PROMPT="You are a code reviewer. Review the following git diff for a pull request.

Check for:
- Security issues (hardcoded secrets, injection vulnerabilities, unsafe operations)
- Logic errors or bugs
- Code quality issues (clarity, maintainability, duplication)
- Missing error handling
- Test coverage gaps

For each issue found, use this format:
**[SEVERITY: BLOCKER|HIGH|MEDIUM|LOW]** \`path/to/file:line\` — Description

At the end, provide:
- **Summary:** 1-2 sentences overall assessment
- **Verdict:** APPROVED | CHANGES NEEDED | BLOCKED

--- PR DIFF ---
$(cat "$DIFF_FILE")"

if command -v claude &>/dev/null; then
  echo "$REVIEW_PROMPT" | claude -p --output-format text 2>/dev/null > "$REVIEW_FILE" || {
    echo "⚠ claude CLI failed — writing placeholder review"
    echo "## Code Review\n\n⚠ Automated review failed to run. Please review manually." > "$REVIEW_FILE"
  }
else
  echo "⚠ claude CLI not installed — writing placeholder review"
  printf "## Code Review\n\n⚠ claude CLI not available on this runner. Install with: npm install -g @anthropic-ai/claude-code\n\nPlease review PR #%s manually." "$PR_NUMBER" > "$REVIEW_FILE"
fi

echo "Review generated ($(wc -c < "$REVIEW_FILE") chars)"

# --- Post review as PR comment ---
echo "Posting review as PR comment..."
"$SCRIPT_DIR/pr-comment.sh" "$REVIEW_FILE" && echo "✓ Review posted" || echo "⚠ Failed to post review comment"

# --- Blocking mode ---
if [ "$BLOCKING" = "true" ]; then
  if grep -qE "\[SEVERITY: (BLOCKER|HIGH)\]" "$REVIEW_FILE" 2>/dev/null; then
    echo "✗ Blocking issues found in review — failing build"
    cat "$REVIEW_FILE"
    rm -f "$REVIEW_FILE" "$DIFF_FILE"
    exit 1
  fi
fi

rm -f "$REVIEW_FILE" "$DIFF_FILE"
echo "=== Code review complete ==="
exit 0