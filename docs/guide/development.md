---
outline: false
---

# Development

Swift 6 package, macOS 13+. Two products: library `HerdrCore`, executable `MacBar` (links Carbon for the global hotkey).

## Repository map {#map}

```text
Sources/HerdrCore/     protocol, discovery, aggregation, enrichment, host raising
Sources/MacBar/        NSStatusItem, dashboard popover, settings, hotkey
Herdr.js               behavior oracle (status order, counts, socket paths)
tests/herdr.test.mjs   Node oracle tests
tests/HerdrCoreTests/  Swift model and protocol tests
tools/demo-server.py   newline JSON fixture
scripts/dev-run.sh     local run (optional --demo)
scripts/package-app.sh pack HerdrBar.app (native; HERDR_BAR_UNIVERSAL=1 for CI)
scripts/install.sh     wrap package-app.sh into ~/Applications (does not kill the old process)
scripts/reload.sh      swift test → install → kill MacBar → open the new extra
.agents/skills/        project skill bodies (test-reload)
.claude/skills         → ../.agents/skills
docs/                  this VitePress site (English root, Chinese under /zh/)
```

Key types:

| Type | Role |
|---|---|
| `HerdrClient` | JSON-RPC read/write |
| `SessionWatcher` | per socket: list + subscribe + reconnect |
| `SessionManager` | discovery, directory watch, focus orchestration |
| `AgentAggregator` | merge online sessions |
| `HerdrLogic` | pure functions: filter, group, count, labels |
| `FocusRaiser` | find and activate the host GUI |
| `StatusPalette` / `AppPreferences` | `herdr-bar.json` |
| `WorkingSpinner` | Darwin `·✢✳✶✻✽` ping-pong |

## Tests {#tests}

```bash
swift test
node --test tests/herdr.test.mjs
```

CI (`.github/workflows/ci.yml`) runs both on `macos-latest`. A separate Pages workflow builds VitePress on Ubuntu. Push a `v*` tag for `.github/workflows/release.yml`: universal `.app`, zip, GitHub Release. The binary is ad-hoc signed (not Developer ID / notarized). `workflow_dispatch` only uploads the artifact.

Behavior changes should include the narrowest useful test. When install, settings, interactions, or requirements change, keep the README and `docs/guide/` in sync.

## Run locally {#run}

```bash
./scripts/dev-run.sh              # default + named sessions
./scripts/dev-run.sh --demo       # fixture
HERDR_SOCKET=/tmp/x.sock ./scripts/dev-run.sh
swift run --package-path . MacBar
```

`--demo` starts `tools/demo-server.py` in the background, points `HERDR_SOCKET` at `/tmp/herdr-demo.sock`, and cleans up on exit.

Source and `swift test` do **not** replace the extra in the menu bar. After MacBar / HerdrCore changes the user should see:

```bash
./scripts/reload.sh              # swift test first
./scripts/reload.sh --skip-tests # this round already passed
./scripts/reload.sh --all-tests  # plus the node oracle
```

`reload.sh` kills every `MacBar` (including ones from `dev-run.sh`), then `open ~/Applications/HerdrBar.app`. Agents follow `.agents/skills/test-reload` (`.claude/skills` is a symlink to `.agents/skills`).

## Docs site {#docs}

This directory is the VitePress source. English is the default locale; Simplified Chinese lives under `/zh/`.

```bash
npm install
npm run docs:dev       # the terminal prints the local URL
npm run docs:build
npm run docs:preview
```

A push to `main` deploys `docs/.vitepress/dist` to GitHub Pages. Project-site `base` is `/herdr-bar/`; local dev uses `/`. The repo is [openalon-org/herdr-bar](https://github.com/openalon-org/herdr-bar).
