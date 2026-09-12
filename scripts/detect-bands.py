#!/usr/bin/env python3
import argparse, json, sys
from pathlib import Path

def parse_bands(path: Path):
    window, mean, stdev = 20, 0.05, 0.05
    in_baseline = False
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        if stripped.startswith("window:"):
            window = int(stripped.split(":", 1)[1].strip())
            in_baseline = False
            continue
        if stripped == "baseline:":
            in_baseline = True
            continue
        if in_baseline:
            if stripped.startswith("mean:"):
                mean = float(stripped.split(":", 1)[1].strip())
            elif stripped.startswith("stdev:"):
                stdev = float(stripped.split(":", 1)[1].strip())
            elif not raw.startswith((" ", "\t")):
                in_baseline = False
    return window, mean, stdev

def main():
    root = Path(__file__).resolve().parents[1]
    p = argparse.ArgumentParser()
    p.add_argument("--fixture", required=True)
    p.add_argument("--config", default=str(root / "bands.yaml"))
    p.add_argument("--window", type=int, default=None)
    args = p.parse_args()
    cfg = Path(args.config)
    if cfg.is_dir():
        cfg = cfg / "bands.yaml"
    yaml_window, mean, stdev = parse_bands(cfg)
    window = args.window if args.window is not None else yaml_window
    values = json.loads(Path(args.fixture).read_text())
    if not isinstance(values, list) or not values:
        print("detect-bands: fixture must be a non-empty JSON list", file=sys.stderr)
        sys.exit(1)
    slice_ = values[-window:]
    rate = sum(slice_) / len(slice_)
    if stdev == 0:
        tier = 3 if rate > mean else 0
    else:
        z = (rate - mean) / stdev
        if z >= 3:
            tier = 3
        elif z >= 2:
            tier = 2
        elif z >= 1:
            tier = 1
        else:
            tier = 0
    action = {0: "ok", 1: "log", 2: "diagnose", 3: "propose"}[tier]
    print(json.dumps({"tier": tier, "action": action, "rate": rate, "mean": mean, "stdev": stdev}))

if __name__ == "__main__":
    main()
