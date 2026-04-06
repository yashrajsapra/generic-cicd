#!/usr/bin/env bash
# Post a comment to the current PR for the detected CI provider.
#
# Usage: pr-comment.sh <body-file>
#   body-file  path to a text/markdown file containing the comment body
#
# Env (both):
#   PR_NUMBER           pull request number (required)
#
# Env (Bitbucket):
#   BB_USER             Bitbucket username
#   BB_TOKEN            Bitbucket app password
#   BB_REPO_FULL_NAME   workspace/repo-slug  (e.g. myworkspace/myrepo)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER="$("$SCRIPT_DIR/detect-provider.sh")"

BODY_FILE="${1:-}"
if [ -z "$BODY_FILE" ]; then
  echo "Usage: pr-comment.sh <body-file>" >&2
  exit 1
fi

if [ ! -f "$BODY_FILE" ]; then
  echo "ERROR: body file not found: $BODY_FILE" >&2
  exit 1
fi

PR_NUMBER="${PR_NUMBER:-}"
if [ -z "$PR_NUMBER" ]; then
  echo "ERROR: PR_NUMBER is not set" >&2
  exit 1
fi

if [ "$PROVIDER" = "github" ]; then
  gh pr comment "$PR_NUMBER" --body-file "$BODY_FILE"

elif [ "$PROVIDER" = "bitbucket" ]; then
  BB_USER="${BB_USER:-}"
  BB_TOKEN="${BB_TOKEN:-}"
  BB_REPO_FULL_NAME="${BB_REPO_FULL_NAME:-}"

  if [ -z "$BB_USER" ] || [ -z "$BB_TOKEN" ] || [ -z "$BB_REPO_FULL_NAME" ]; then
    echo "ERROR: BB_USER, BB_TOKEN, and BB_REPO_FULL_NAME must all be set for Bitbucket" >&2
    exit 1
  fi

  BODY="$(cat "$BODY_FILE")"
  # Escape for JSON
  BODY_JSON="$(printf '%s' "$BODY" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')"

  curl -sf -u "$BB_USER:$BB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":{\"raw\":$BODY_JSON}}" \
    "https://api.bitbucket.org/2.0/repositories/$BB_REPO_FULL_NAME/pullrequests/$PR_NUMBER/comments"

else
  echo "ERROR: Unknown provider '$PROVIDER'" >&2
  exit 1
fi
