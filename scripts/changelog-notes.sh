#!/bin/bash
# Print the CHANGELOG.md section for one version (GitHub Release body).
# Usage: scripts/changelog-notes.sh <version>
# Accepts 0.1.1 or v0.1.1. Fails if that heading is missing or the section is empty.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ver="${1:-}"
ver="${ver#v}"
if [[ -z "$ver" ]]; then
  echo "usage: changelog-notes.sh <version>" >&2
  exit 2
fi

file="$root/CHANGELOG.md"
if [[ ! -f "$file" ]]; then
  echo "CHANGELOG.md missing" >&2
  exit 1
fi

notes="$(
  awk -v ver="$ver" '
    /^## \[/ {
      if (found) exit
      split($0, parts, /[\[\]]/)
      if (parts[2] == ver) {
        found = 1
        next
      }
      next
    }
    found { print }
    END { if (!found) exit 1 }
  ' "$file"
)" || {
  echo "CHANGELOG.md has no ## [$ver] section" >&2
  exit 1
}

trimmed="$(printf '%s' "$notes" | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d')"
if [[ -z "$trimmed" ]]; then
  echo "CHANGELOG.md section for $ver is empty" >&2
  exit 1
fi
printf '%s\n' "$trimmed"
