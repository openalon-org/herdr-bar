# herdr-bar

[English](README.md) · [中文](README.zh.md) · [Docs](https://openalon.com/herdr-bar/)

[![CI](https://github.com/openalon-org/herdr-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/openalon-org/herdr-bar/actions/workflows/ci.yml)
[![Docs](https://github.com/openalon-org/herdr-bar/actions/workflows/docs.yml/badge.svg)](https://openalon.com/herdr-bar/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)](https://github.com/openalon-org/herdr-bar/releases)
[![Herdr 0.8+](https://img.shields.io/badge/Herdr-0.8%2B-5F87FF.svg)](https://herdr.dev/)

**A Herdr companion in the menu bar**

See every coding agent at a glance. Jump to the one that needs you. No polling. No new panes.

[Install](https://openalon.com/herdr-bar/guide/installation.html) · [Changelog](https://openalon.com/herdr-bar/changelog.html)

<p align="center">
  <a href="https://openalon.com/herdr-bar/">
    <img src="docs/public/app-mark.png" alt="HerdrBar" height="72">
  </a>
</p>

| 👁 [Menu-bar glance](https://openalon.com/herdr-bar/guide/usage.html) | ⚡ [Event-driven](https://openalon.com/herdr-bar/guide/protocol.html) | 🎯 [Priority focus](https://openalon.com/herdr-bar/guide/status.html) |
|---|---|---|
| Done and Working stay on the extra. Blocked and Unknown join when they need you. Idle lives behind the dashboard eye. | `events.subscribe` invalidates the snapshot; `agent.list` refreshes it. Never poll Herdr on a timer. | Option-click jumps to the highest-priority agent — blocked, then done, working, unknown, idle. |
| **🪟 [Focus, never create](https://openalon.com/herdr-bar/guide/architecture.html#focus-raiser)** | **🧩 [Every live session](https://openalon.com/herdr-bar/guide/architecture.html#discovery)** | **🎨 [Claude Code palette](https://openalon.com/herdr-bar/guide/configuration.html)** |
| `agent.focus`, then `tab.focus` so the attached TUI follows, then raise that session’s host terminal. Never open a window, pane, or agent. | Discover default and named sessions (`work`, …) and identify agents as `(sessionName, pane_id)`. | Defaults match Claude’s terminal tabs; working uses the CLI spinner terracotta. Override from the gear. |

> **What this is**
>
> **herdr-bar** is the macOS menu-bar companion for [Herdr](https://herdr.dev/). It talks to Herdr’s Unix sockets, folds every live session into a glanceable count, and jumps you back to a pane that already exists.
>
> Requires Herdr 0.8+ and macOS 13+. The app is an `LSUIElement` — it never appears in the Dock.

<p align="center">
  <img src="docs/public/dashboard.png" alt="Dashboard popover with session chips and Working rows" width="280">
  <img src="docs/public/settings.png" alt="Settings: Open at login, keyboard, About" width="280">
  <img src="docs/public/widget.png" alt="Desktop widget All-scope list" width="220">
</p>

## What it is

Herdr owns the agents. The terminal owns the TUI. herdr-bar is the glance in between — it never starts Herdr and never creates a pane.

```mermaid
flowchart LR
  subgraph host [Your Mac]
    TUI["Terminal<br/>herdr TUI"]
    Extra["herdr-bar<br/>menu extra"]
    Widget["Desktop widget<br/>read-only list"]
  end
  Herdr["herdr server<br/>herdr.sock"]
  TUI -->|"attach / session attach"| Herdr
  Extra -->|"events.subscribe<br/>agent.list"| Herdr
  Extra -->|"agent.focus then<br/>tab.focus / pane.focus"| Herdr
  Extra -->|"raise host"| TUI
  Extra -->|"widget-snapshot.json"| Widget
  Widget -->|"herdr-bar://focus"| Extra
```

Without it you attach each session and hunt for the pane that needs you. With it: Option-click the extra for the highest-priority agent, or open the dashboard and click a row.

## FAQ

**What is herdr-bar?**
A macOS menu-bar extra for [Herdr](https://herdr.dev/). It does not start Herdr. It discovers `herdr.sock`, shows Done / Working counts, and Option-click focuses the highest-priority agent.

**How do I install it?**
Download a tagged `HerdrBar-*-macos.zip` from [GitHub Releases](https://github.com/openalon-org/herdr-bar/releases), or `./scripts/install.sh` from source. The zip is ad-hoc signed — first launch may need right-click → Open. Details: [Install](https://openalon.com/herdr-bar/guide/installation.html).

**Does it create new panes?**
No. Focus is `agent.focus`, then `tab.focus` / `pane.focus` so the attached TUI follows, then raising the host terminal. See [Usage](https://openalon.com/herdr-bar/guide/usage.html) and [Architecture](https://openalon.com/herdr-bar/guide/architecture.html).
