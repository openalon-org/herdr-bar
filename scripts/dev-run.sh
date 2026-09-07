#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ "${1:-}" == "--demo" ]]; then
  socket="${HERDR_SOCKET:-/tmp/herdr-demo.sock}"
  python3 "$root/tools/demo-server.py" --socket "$socket" &
  demo_pid=$!
  trap 'kill "$demo_pid" 2>/dev/null || true' EXIT
  export HERDR_SOCKET="$socket"
  sleep 0.2
fi

swift run --package-path "$root" MacBar
