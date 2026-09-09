---
outline: false
description: Build, test, and reload herdr-bar locally. Swift package plus the VitePress docs site.
---

# Development

Swift 6 package, macOS 13+. Three products: library `HerdrCore`, executable `MacBar` (Carbon, ServiceManagement, WidgetKit), executable `HerdrWidget` (compile-check only). The gallery widget is a real app-extension from `WidgetExtension/` (`xcodebuild`), nested as `HerdrWidget.appex`.

## Repository map {#map}

```text
Sources/HerdrCore/     protocol, discovery, aggregation, enrichment, host raising, widget snapshot
Sources/MacBar/        NSStatusItem, dashboard popover, settings, hotkey, snapshot publisher
Sources/HerdrWidget/   WidgetKit Medium / Large (source for the appex)
WidgetExtension/       XcodeGen app-extension project; package-app.sh runs xcodebuild
Herdr.js               behavior oracle (status order, counts, socket paths)
tests/herdr.test.mjs   Node oracle tests
tests/HerdrCoreTests/  Swift model and protocol tests
tools/demo-server.py   newline JSON fixture
scripts/dev-run.sh     local run (optional --demo)
scripts/package-app.sh pack HerdrBar.app (native; HERDR_BAR_UNIVERSAL=1 for CI)
scripts/render-app-icon.swift SF Symbol `cpu` → AppIcon.icns (called from package-app.sh)
scripts/install.sh     wrap package-app.sh into ~/Applications (does not kill the old process)
scripts/reload.sh      swift test → install → kill MacBar + leftover HerdrWidget → open the extra
scripts/changelog-notes.sh  one CHANGELOG.md section → GitHub Release body
CHANGELOG.md           Keep a Changelog (docs /changelog includes this file)
.agents/skills/        project skill bodies (test-reload, release)
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
| `LoginItem` | open-at-login UI mapping (`SMAppService` lives in MacBar) |
| `BrandMark` | `chrome` SF Symbol in the dashboard header; `badge` icns in About |
| `WidgetSnapshot` | extra → `widget-snapshot.json` → WidgetKit; `herdr-bar://focus` |
| `WorkingSpinner` | Darwin `·✢✳✶✻✽` ping-pong |

## Tests {#tests}

```bash
swift test
node --test tests/herdr.test.mjs tests/changelog.test.mjs
```

CI (`.github/workflows/ci.yml`) runs both on `macos-latest`. The Ubuntu `docs` job builds VitePress and then `tests/seo.test.mjs` (canonical, hreflang, sitemap, robots). A separate Pages workflow deploys the same build. Push a `v*` tag for `.github/workflows/release.yml`: universal `.app`, zip, GitHub Release whose body is `scripts/changelog-notes.sh` for that version. The tag must match a `## [X.Y.Z]` heading in `CHANGELOG.md`. The binary is ad-hoc signed (not Developer ID / notarized). `workflow_dispatch` only uploads the artifact.

Behavior changes should include the narrowest useful test. When install, settings, interactions, or requirements change, keep the README and `docs/guide/` in sync. User-facing history is `CHANGELOG.md` at release time (skill `release`).

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

`reload.sh` kills every `MacBar` (including ones from `dev-run.sh`) and a leftover `HerdrWidget` process, then `open ~/Applications/HerdrBar.app`. Agents follow `.agents/skills/test-reload` (`.claude/skills` is a symlink to `.agents/skills`).

## Docs site {#docs}

This directory is the VitePress source. English is the default locale; Simplified Chinese lives under `/zh/`.

```bash
npm install
npm run docs:dev       # the terminal prints the local URL
npm run docs:build
npm run docs:preview
```

A push to `main` deploys `docs/.vitepress/dist` to GitHub Pages. Project-site `base` is `/herdr-bar/`; local dev uses `/`. Canonical, Open Graph, JSON-LD, `sitemap.xml`, and `robots.txt` all share `https://openalon.com/herdr-bar/` (`docs/.vitepress/seo.ts`). Per-page descriptions and FAQ JSON-LD are extracted from the markdown at build time (`docs/.vitepress/from-markdown.mjs`) — a new `docs/guide/*.md` plus its `docs/zh/` twin picks them up with no extra table. Override with frontmatter `description:` when the first paragraph is a poor snippet (architecture, protocol, invariants, development, changelog already do). Missing `docs/zh/` twins omit that hreflang instead of pointing at a 404. The social card is `docs/public/og.png` (1200×630). The repo is [openalon-org/herdr-bar](https://github.com/openalon-org/herdr-bar). `/changelog` includes the root `CHANGELOG.md` — do not copy notes into `docs/`. After the first deploy of a sitemap, submit `https://openalon.com/herdr-bar/sitemap.xml` in [Google Search Console](https://search.google.com/search-console).
