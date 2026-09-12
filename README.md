# herdr-bar

[![CI](https://github.com/openalon-org/herdr-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/openalon-org/herdr-bar/actions/workflows/ci.yml)
[![Docs](https://github.com/openalon-org/herdr-bar/actions/workflows/docs.yml/badge.svg)](https://openalon.com/herdr-bar/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)](https://github.com/openalon-org/herdr-bar/releases)

See every coding agent at a glance. Jump to the one that needs you.

A macOS menu-bar companion for [Herdr](https://herdr.dev/). It talks to Herdr’s Unix sockets, updates on events instead of polling, and folds every live session into one extra.

**Docs:** [openalon.com/herdr-bar](https://openalon.com/herdr-bar/) · [中文](https://openalon.com/herdr-bar/zh/)

## Highlights

- **Glance, not inventory** — Done and Working stay on the extra (zeros included). Blocked / Unknown join when they need you. Idle lives in the dashboard.
- **Priority focus** — Option-click jumps `blocked` → `done` → `working` → `unknown` → `idle`.
- **Event-driven** — `events.subscribe` invalidates; `agent.list` refreshes. Never poll Herdr on a timer.
- **Every live session** — default plus named sessions such as `work`. Identity is `(sessionName, pane_id)`.
- **Focus, never create** — `agent.focus`, then `tab.focus` / `pane.focus` so the attached TUI follows (Herdr 0.9 keeps that view per client), then raise the host terminal. No new window, pane, or agent.
- **Reconnect** — if Herdr restarts, the extra finds the socket again.

## Install

Requires **macOS 13+**, **Herdr 0.8+**, and (for source builds) **Swift**.

### GitHub Release

Tagged `v*` releases attach a universal `HerdrBar-*-macos.zip`. The binary is **ad-hoc signed** — no Developer ID, no notarization.

```bash
xattr -cr HerdrBar.app
open HerdrBar.app
```

Gatekeeper quarantines browser downloads. First launch: right-click → Open.

### From source

```bash
git clone https://github.com/openalon-org/herdr-bar.git
cd herdr-bar
./scripts/install.sh
open ~/Applications/HerdrBar.app
```

The app is an `LSUIElement` — no Dock icon. After a local extra / core change, source is still not the running extra:

```bash
./scripts/reload.sh
```

Throwaway run without packing a bundle:

```bash
./scripts/dev-run.sh
./scripts/dev-run.sh --demo   # bundled fixture, no Herdr required
```

Pin a single socket with `HERDR_SOCKET=/path/to/herdr.sock`.

## Use

| Gesture | Action |
|---|---|
| Left-click extra | Open the dashboard |
| Option-click extra | Focus the highest-priority agent |
| Right-click extra | Refresh with `agent.list` now |
| Click a row | Focus that pane and raise its terminal |
| Session-chip arrow | Named session only: raise that session’s terminal (chip body still filters; last selected pane stays) |
| Desktop widget | Notification Center gallery: Medium / Large list. Tap a row to focus that pane |
| Enter | Focus the highlighted row (priority agent if none) |
| Arrow keys | Up/down: tasks. Left/right: session chips, or folders when only one session is online |
| Eye | Notification mode (default): hide idle |
| Gear | Open at login, status colors, opener, and Check for Updates |

Status colors default to [Claude Code](https://code.claude.com/docs)’s terminal tab palette; working uses the CLI spinner terracotta. Overrides live in `~/.config/herdr/herdr-bar.json`. Details: [Usage](https://openalon.com/herdr-bar/guide/usage.html), [Configuration](https://openalon.com/herdr-bar/guide/configuration.html).

## Develop

```bash
swift test
node --test tests/herdr.test.mjs tests/changelog.test.mjs
```

`Herdr.js` is the behavior oracle for status order, counts, and socket paths. See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

Docs site (VitePress):

```bash
npm install
npm run docs:dev
```

Push to `main` deploys GitHub Pages. Canonical, Open Graph, JSON-LD, sitemap, and robots all share `https://openalon.com/herdr-bar/`. Descriptions and FAQ schema are extracted from each markdown page at build time. A `v*` tag runs the Release workflow (zip + GitHub Release). The Release body is the matching `CHANGELOG.md` section, not GitHub’s auto-generated notes. Manual **Run workflow** on that job only uploads an Actions artifact — it does not publish a Release. User-facing history: [Changelog](https://openalon.com/herdr-bar/changelog.html).

## Architecture

Each discovered socket gets a `SessionWatcher`: a one-shot command socket for `agent.list` / `agent.focus` / `tab.focus` / `pane.focus`, plus a long-lived `events.subscribe` connection. Events invalidate; a fresh `agent.list` is truth. `AgentAggregator` merges online sessions. `HerdrLogic` is a Swift port of `Herdr.js`.

## License

MIT. © openalon
