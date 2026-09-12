#!/bin/bash
set -euo pipefail
if [[ -n "${HERDR_BAR_ALLOW_ORACLE:-}" ]]; then
  exit 0
fi
dir="$(cd "$(dirname "$0")" && pwd)"
payload=$(cat || true)
printf "%s" "$payload" | python3 "$dir/protect-oracle.py"
