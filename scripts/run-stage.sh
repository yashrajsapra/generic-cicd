#!/usr/bin/env bash
# Run a CI stage: {stage}.pre hook → command → {stage}.post hook.
# Exit code mirrors the command's exit code (post hook runs regardless).
#
# Usage: run-stage.sh <stage> <command>
#
# Env:
#   HOOKS_DIR   directory containing hook scripts (default: .cicd/hooks)
set -uo pipefail

STAGE="${1:-}"
COMMAND="${2:-}"

if [ -z "$STAGE" ] || [ -z "$COMMAND" ]; then
  echo "Usage: run-stage.sh <stage> <command>" >&2
  exit 1
fi

HOOKS_DIR="${HOOKS_DIR:-.cicd/hooks}"

run_hook() {
  local hook="$HOOKS_DIR/${STAGE}.${1}.sh"
  if [ -f "$hook" ]; then
    echo "[run-stage] running hook: $hook"
    # shellcheck disable=SC1090
    bash "$hook"
  fi
}

run_hook "pre"

eval "$COMMAND"
EXIT_CODE=$?

run_hook "post"

exit $EXIT_CODE
