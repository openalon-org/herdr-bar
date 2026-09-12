#!/usr/bin/env python3
from __future__ import annotations
import json, os, sys

def _payload_raw() -> str:
    raw = sys.stdin.read()
    if raw.strip():
        return raw
    for key in ("CLAUDE_HOOK_PAYLOAD", "CLAUDE_TOOL_INPUT"):
        value = os.environ.get(key, "")
        if value.strip():
            return value
    return ""

def main() -> int:
    if os.environ.get("HERDR_BAR_ALLOW_ORACLE"):
        return 0
    raw = _payload_raw()
    if not raw.strip():
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as err:
        print(f"protect-oracle: invalid JSON ({err})", file=sys.stderr)
        return 2
    if not isinstance(payload, dict):
        payload = {}
    tool_input = payload.get("tool_input") or payload
    if not isinstance(tool_input, dict):
        tool_input = {}
    path = tool_input.get("file_path") or payload.get("file_path") or ""
    if not isinstance(path, str):
        path = ""
    norm = path.replace(chr(92), "/")
    if norm.endswith("Herdr.js") or norm.endswith("tests/herdr.test.mjs"):
        print(
            "protect-oracle: blocked (Herdr.js oracle). "
            "Set HERDR_BAR_ALLOW_ORACLE=1 if the port contract must change.",
            file=sys.stderr,
        )
        return 2
    return 0

if __name__ == "__main__":
    sys.exit(main())
