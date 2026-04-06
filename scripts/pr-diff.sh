#!/usr/bin/env bash
# Fetch the PR diff for the current CI provider and write it to stdout.
#
# Env (GitHub):
#   PR_NUMBER           pull request number (required)
#
# Env (Bitbucket):
#   PR_NUMBER           pull request number (required)
#   BB_USER             Bitbucket username
#   BB_TOKEN            Bitbucket app password
#   BB_REPO_FULL_NAME   workspace/repo-slug  (e.g. myworkspace/myrepo)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER="$("$SCRIPT_DIR/detect-provider.sh")"

PR_NUMBER="${PR_NUMBER:-}"
if [ -z "$PR_NUMBER" ]; then
  echo "ERROR: PR_NUMBER is not set" >&2
  exit 1
fi

if [ "$PROVIDER" = "github" ]; then
  gh pr diff "$PR_NUMBER"

elif [ "$PROVIDER" = "bitbucket" ]; then
  BB_USER="${BB_USER:-}"
  BB_TOKEN="${BB_TOKEN:-}"
  BB_REPO_FULL_NAME="${BB_REPO_FULL_NAME:-}"

  if [ -z "$BB_USER" ] || [ -z "$BB_TOKEN" ] || [ -z "$BB_REPO_FULL_NAME" ]; then
    echo "ERROR: BB_USER, BB_TOKEN, and BB_REPO_FULL_NAME must all be set for Bitbucket" >&2
    exit 1
  fi

  curl -sf -u "$BB_USER:$BB_TOKEN" \
    "https://api.bitbucket.org/2.0/repositories/$BB_REPO_FULL_NAME/pullrequests/$PR_NUMBER/diff"

else
  echo "ERROR: Unknown provider '$PROVIDER'" >&2
  exit 1
fi
