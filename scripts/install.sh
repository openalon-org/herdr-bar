#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/package-app.sh" "$HOME/Applications/HerdrBar.app"
echo "Open with: open $HOME/Applications/HerdrBar.app"
