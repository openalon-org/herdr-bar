#!/bin/bash
set -euo pipefail
if [[ -n "${RELEASE_APPROVAL:-}" ]]; then
  exit 0
fi
dir="$(cd "$(dirname "$0")" && pwd)"
payload=$(cat || true)
printf "%s" "$payload" | python3 "$dir/production-gate.py"
