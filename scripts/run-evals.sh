#!/bin/bash
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
python3 "$dir/run-evals.py"
