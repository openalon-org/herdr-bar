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

def block(reason: str) -> int:
    print(
        f"depersonalize: blocked ({reason}). "
        "Use /Users/me, /home/user, ~/, and session work. "
        "See AGENTS.md.",
        file=sys.stderr,
    )
    return 2

def main() -> int:
    raw = _payload_raw()
    if not raw.strip():
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as err:
        print(f"depersonalize: invalid JSON ({err})", file=sys.stderr)
        return 2
    if not isinstance(payload, dict):
        payload = {}
    tool_input = payload.get("tool_input") or payload
    if not isinstance(tool_input, dict):
        tool_input = {}
    # file_path is the clone on disk (a real home plus a local folder).
    # Only published content is gated.
    chunks = [
        tool_input.get("content") or "",
        tool_input.get("new_string") or "",
        tool_input.get("old_string") or "",
    ]
    text = "\n".join(c for c in chunks if isinstance(c, str))
    # Documented local-project token from AGENTS.md, assembled so this
    # file does not itself contain the forbidden spelling.
    local_root = "workspace" + str(2)
    if re.search(rf"/{re.escape(local_root)}/|{re.escape(local_root)}/", text):
        return block("local project path")
    for m in re.finditer(r"/Users/([A-Za-z0-9._-]+)", text):
        if m.group(1) != "me":
            return block(f"/Users/{m.group(1)}")
    for m in re.finditer(r"/home/([A-Za-z0-9._-]+)", text):
        if m.group(1) != "user":
            return block(f"/home/{m.group(1)}")
    reserved = "ed" + "en"
    if re.search(
        rf"sessions/{reserved}\b|session(?:Name)?[\"\s:=]+{reserved}\b|\"{reserved}\"",
        text,
        re.I,
    ):
        return block("reserved session name")
    return 0

if __name__ == "__main__":
    sys.exit(main())
