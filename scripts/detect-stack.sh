#!/usr/bin/env bash
# Detect the project stack and optionally return the default command for a stage.
# Usage:
#   detect-stack.sh              -> outputs: node | python | go | dotnet | unknown
#   detect-stack.sh --command <stage>  -> outputs default command for that stage

set -euo pipefail

detect() {
  if [ -f "package.json" ]; then echo "node"
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then echo "python"
  elif [ -f "go.mod" ]; then echo "go"
  elif ls ./*.csproj 2>/dev/null | head -1 | grep -q .; then echo "dotnet"
  else echo "unknown"
  fi
}

if [ "${1:-}" = "--command" ]; then
  STAGE="${2:-}"
  STACK=$(detect)
  case "$STACK:$STAGE" in
    node:lint)    echo "npm run lint" ;;
    node:test)    echo "npm test" ;;
    node:build)   echo "npm run build" ;;
    python:lint)  echo "flake8 ." ;;
    python:test)  echo "pytest" ;;
    python:build) echo "python -m build" ;;
    go:lint)      echo "golangci-lint run" ;;
    go:test)      echo "go test ./..." ;;
    go:build)     echo "go build ./..." ;;
    dotnet:lint)  echo "dotnet format --verify-no-changes" ;;
    dotnet:test)  echo "dotnet test" ;;
    dotnet:build) echo "dotnet build" ;;
    *) echo "echo 'No default command for $STAGE on $STACK stack -- configure in .cicd/config.yml'" ;;
  esac
else
  detect
fi