#!/bin/bash
# Rebuild the installed extra from this tree, then replace the running one.
# Source is not the live app — tests + install.sh + restart.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

skip_tests=0
all_tests=0
usage() {
  cat <<'EOF'
Usage: scripts/reload.sh [--skip-tests] [--all-tests]

  (default)     swift test, then install + restart ~/Applications/HerdrBar.app
  --all-tests   also run node --test tests/herdr.test.mjs
  --skip-tests  install + restart only (agent already ran tests this turn)

Kills every MacBar process (installed extra and `swift run`) and a leftover
HerdrWidget .appex, then opens the bundle. Do not run alongside scripts/dev-run.sh.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-tests) skip_tests=1 ;;
    --all-tests) all_tests=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "unknown arg: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if (( skip_tests == 0 )); then
  swift test --package-path "$root"
  if (( all_tests )); then
    node --test "$root/tests/herdr.test.mjs"
  fi
fi

"$root/scripts/install.sh"

if pgrep -x MacBar >/dev/null; then
  killall MacBar 2>/dev/null || true
  for _ in $(seq 1 20); do
    pgrep -x MacBar >/dev/null || break
    sleep 0.1
  done
  if pgrep -x MacBar >/dev/null; then
    killall -9 MacBar 2>/dev/null || true
    sleep 0.2
  fi
fi

# chronod keeps the previous .appex process; a new MacBar is not enough.
if pgrep -x HerdrWidget >/dev/null; then
  killall HerdrWidget 2>/dev/null || true
  sleep 0.2
  if pgrep -x HerdrWidget >/dev/null; then
    killall -9 HerdrWidget 2>/dev/null || true
    sleep 0.1
  fi
fi

open "$HOME/Applications/HerdrBar.app"

for _ in $(seq 1 20); do
  if pgrep -x MacBar >/dev/null; then
    echo "Reloaded $HOME/Applications/HerdrBar.app (pid $(pgrep -x MacBar | tr '\n' ' '))"
    exit 0
  fi
  sleep 0.1
done

echo "Installed but MacBar did not stay up" >&2
exit 1
