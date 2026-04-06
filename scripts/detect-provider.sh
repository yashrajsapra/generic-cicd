#!/usr/bin/env bash
# Detect which CI provider is running this pipeline.
# Outputs: github | bitbucket | unknown
# Exit 1 if provider cannot be determined.
set -euo pipefail

if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  echo "github"
elif [ -n "${BITBUCKET_BUILD_NUMBER:-}" ]; then
  echo "bitbucket"
else
  echo "unknown" >&2
  exit 1
fi
