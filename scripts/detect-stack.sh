#!/usr/bin/env bash
# Detect the project tech stack by probing well-known marker files.
# Usage: detect-stack.sh [directory]   (default: current directory)
# Outputs: node | python | go | dotnet | unknown
set -euo pipefail

TARGET_DIR="${1:-.}"

if [ -f "$TARGET_DIR/package.json" ]; then
  echo "node"
elif [ -f "$TARGET_DIR/requirements.txt" ] || \
     [ -f "$TARGET_DIR/setup.py" ] || \
     [ -f "$TARGET_DIR/pyproject.toml" ]; then
  echo "python"
elif [ -f "$TARGET_DIR/go.mod" ]; then
  echo "go"
elif find "$TARGET_DIR" -maxdepth 1 -name "*.csproj" | grep -q .; then
  echo "dotnet"
else
  echo "unknown"
fi
