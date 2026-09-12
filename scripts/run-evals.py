#!/usr/bin/env python3
import json, sys
from pathlib import Path

def check(path, root):
    data = json.loads(path.read_text())
    for key in ("id", "prompt", "must_hold"):
        if key not in data:
            print(path.name + ": missing " + key, file=sys.stderr)
            return 1
    if not isinstance(data["must_hold"], list) or not data["must_hold"]:
        print(path.name + ": must_hold empty", file=sys.stderr)
        return 1
    for i, item in enumerate(data["must_hold"]):
        if not isinstance(item, dict) or "file" not in item or "text" not in item:
            print(path.name + ": must_hold[" + str(i) + "] needs file+text", file=sys.stderr)
            return 1
        rel = item["file"]
        target = root / rel
        if not target.is_file():
            print(path.name + ": missing file " + rel, file=sys.stderr)
            return 1
        body = target.read_text()
        if item["text"] not in body:
            print(path.name + ": text not found in " + rel + ": " + repr(item["text"]), file=sys.stderr)
            return 1
    print("ok " + data["id"])
    return 0

def main():
    here = Path(__file__).resolve().parent
    root = here.parent
    cases = sorted((root / "sdlc/evals/cases").glob("*.json"))
    if not cases:
        print("run-evals: no cases", file=sys.stderr)
        return 1
    fail = 0
    for path in cases:
        fail |= check(path, root)
    return 1 if fail else 0

if __name__ == "__main__":
    sys.exit(main())
