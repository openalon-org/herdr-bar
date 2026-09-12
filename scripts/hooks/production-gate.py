#!/usr/bin/env python3
from __future__ import annotations
import json, os, re, sys

def _payload_raw() -> str:
    raw = sys.stdin.read()
    if raw.strip():
        return raw
    for key in ("CLAUDE_HOOK_PAYLOAD", "CLAUDE_TOOL_INPUT"):
        value = os.environ.get(key, "")
        if value.strip():
            return value
    return ""

def blocked(reason: str) -> int:
    print(
        f"production-gate: blocked ({reason}). "
        "A human tags v* and GitHub Release publishes the zip. "
        "Set RELEASE_APPROVAL to proceed.",
        file=sys.stderr,
    )
    return 2

def main() -> int:
    if os.environ.get("RELEASE_APPROVAL"):
        return 0
    raw = _payload_raw()
    if not raw.strip():
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as err:
        print(f"production-gate: invalid JSON ({err})", file=sys.stderr)
        return 2
    if not isinstance(payload, dict):
        payload = {}
    tool_input = payload.get("tool_input") or payload
    if not isinstance(tool_input, dict):
        tool_input = {}
    command = tool_input.get("command") or payload.get("command") or ""
    if not isinstance(command, str):
        command = ""
    if re.search(r"\bgh\s+release\b", command):
        return blocked("gh release")
    if re.search(r"\bgit\s+push\b", command):
        if re.search(r"(^|[\s:])v\d+\.\d+", command) or "refs/tags/v" in command:
            return blocked("git push of v* tag")
        if re.search(r"\s--tags\b", command):
            return blocked("git push --tags")
    lower = command.lower()
    if re.search(r"\bdeploy\b", lower) and re.search(r"\bproduction\b", lower):
        return blocked("deploy + production")
    return 0

if __name__ == "__main__":
    sys.exit(main())
