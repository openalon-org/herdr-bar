#!/bin/bash
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
payload=$(cat || true)
printf "%s" "$payload" | python3 "$dir/depersonalize.py"
