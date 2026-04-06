#!/usr/bin/env bash
# Merge .cicd/config.yml over config/defaults.yml and output the resolved value
# for a given dotted key.
#
# Usage: load-config.sh <key>
# Example: load-config.sh stages.lint.enabled
#
# Env:
#   CICD_CONFIG_PATH  path to caller config (default: .cicd/config.yml)
#
# Requires: yq (mikefarah/yq v4) OR python3 with PyYAML
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS="$SCRIPT_DIR/../config/defaults.yml"
KEY="${1:-}"

if [ -z "$KEY" ]; then
  echo "Usage: load-config.sh <key>" >&2
  exit 1
fi

OVERRIDE="${CICD_CONFIG_PATH:-.cicd/config.yml}"

# ── yq path (mikefarah/yq v4+) ──────────────────────────────────────────────
if command -v yq >/dev/null 2>&1; then
  if [ -f "$OVERRIDE" ]; then
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$DEFAULTS" "$OVERRIDE" | yq eval ".$KEY"
  else
    yq eval ".$KEY" "$DEFAULTS"
  fi
  exit $?
fi

# ── Python fallback ──────────────────────────────────────────────────────────
python3 - "$DEFAULTS" "$OVERRIDE" "$KEY" <<'PYEOF'
import sys, os

try:
    import yaml
except ImportError:
    print("ERROR: neither yq nor PyYAML (python3-yaml) is available", file=sys.stderr)
    sys.exit(1)

base_file, override_file, key = sys.argv[1], sys.argv[2], sys.argv[3]

def deep_merge(base, override):
    for k, v in override.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base

with open(base_file) as f:
    config = yaml.safe_load(f) or {}

if os.path.isfile(override_file):
    with open(override_file) as f:
        override = yaml.safe_load(f) or {}
    deep_merge(config, override)

val = config
try:
    for part in key.split('.'):
        val = val[part]
except (KeyError, TypeError):
    print("null")
    sys.exit(0)

if isinstance(val, bool):
    print(str(val).lower())
elif val is None:
    print("null")
else:
    print(val)
PYEOF
