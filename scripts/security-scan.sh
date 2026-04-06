#!/usr/bin/env bash
# Security scan stage: secret scanning + dependency audit
# Runs gitleaks (secrets) and stack-appropriate dependency audit.
# Non-fatal if tools are missing -- warns and continues.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Security Scan ==="

# --- Secret scanning (gitleaks) ---
echo ""
echo "--- Secret Scanning (gitleaks) ---"
if command -v gitleaks &>/dev/null; then
  gitleaks detect --source "$REPO_ROOT" --no-banner --exit-code 1 \
    && echo "✓ No secrets detected" \
    || { echo "✗ Secrets detected -- review gitleaks output above"; SCAN_FAILED=1; }
else
  echo "⚠ gitleaks not installed -- installing..."
  if command -v apt-get &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq gitleaks 2>/dev/null \
      && gitleaks detect --source "$REPO_ROOT" --no-banner --exit-code 1 \
      || echo "⚠ gitleaks install failed -- skipping secret scan"
  else
    echo "⚠ Cannot auto-install gitleaks -- skipping secret scan"
  fi
fi

# --- Dependency audit ---
echo ""
echo "--- Dependency Audit ---"
STACK=$("$SCRIPT_DIR/detect-stack.sh")
echo "Detected stack: $STACK"

case "$STACK" in
  node)
    if command -v npm &>/dev/null; then
      npm audit --audit-level=high --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
vulns = data.get('metadata', {}).get('vulnerabilities', {})
high = vulns.get('high', 0) + vulns.get('critical', 0)
print(f'Vulnerabilities -- high: {high}, moderate: {vulns.get(\"moderate\",0)}, low: {vulns.get(\"low\",0)}')
sys.exit(1 if high > 0 else 0)
" || { echo "✗ High/critical npm vulnerabilities found"; SCAN_FAILED=1; }
    else
      echo "⚠ npm not available -- skipping dependency audit"
    fi ;;
  python)
    if command -v pip-audit &>/dev/null; then
      pip-audit --desc || { echo "✗ Python vulnerabilities found"; SCAN_FAILED=1; }
    elif command -v pip3 &>/dev/null; then
      pip3 install pip-audit -q && pip-audit --desc \
        || echo "⚠ pip-audit install failed -- skipping"
    else
      echo "⚠ pip-audit not available -- skipping dependency audit"
    fi ;;
  go)
    if command -v go &>/dev/null; then
      go mod verify && echo "✓ Go modules verified" \
        || { echo "✗ Go module verification failed"; SCAN_FAILED=1; }
    else
      echo "⚠ go not available -- skipping"
    fi ;;
  dotnet)
    if command -v dotnet &>/dev/null; then
      dotnet list package --vulnerable 2>/dev/null | grep -i "has the following vulnerable packages" \
        && { echo "✗ Vulnerable .NET packages found"; SCAN_FAILED=1; } \
        || echo "✓ No vulnerable .NET packages"
    else
      echo "⚠ dotnet not available -- skipping"
    fi ;;
  *)
    echo "⚠ Unknown stack -- skipping dependency audit" ;;
esac

echo ""
echo "=== Scan complete ==="
exit "${SCAN_FAILED:-0}"
