---
layout: home

hero:
  name: herdr-bar
  text: A Herdr companion in the menu bar
  tagline: See every coding agent at a glance. Jump to the one that needs you. No polling. No new panes.
  image:
    src: /herdr-bar-icon.svg
    alt: herdr-bar
  actions:
    - theme: brand
      text: Install
      link: /guide/installation
    - theme: alt
      text: Changelog
      link: /changelog

features:
  - icon: 👁
    title: Menu-bar glance
    details: Done and Working stay on the extra. Blocked and Unknown join when they need you. Idle lives behind the dashboard eye.
    link: /guide/usage
  - icon: ⚡
    title: Event-driven
    details: events.subscribe invalidates the snapshot; agent.list refreshes it. Never poll Herdr on a timer.
    link: /guide/protocol
  - icon: 🎯
    title: Priority focus
    details: Option-click jumps to the highest-priority agent — blocked, then done, working, unknown, idle.
    link: /guide/status
  - icon: 🪟
    title: Focus, never create
    details: agent.focus, then raise the terminal already hosting that session’s TUI. Never open a window, pane, or agent.
    link: /guide/architecture#focus-raiser
  - icon: 🧩
    title: Every live session
    details: Discover default and named sessions (`work`, …) and identify agents as (sessionName, pane_id).
    link: /guide/architecture#discovery
  - icon: 🎨
    title: Claude Code palette
    details: Defaults match Claude’s terminal tabs; working uses the CLI spinner terracotta. Override from the gear.
    link: /guide/configuration
---

::: info What this is
**herdr-bar** is the macOS menu-bar companion for [Herdr](https://herdr.dev/). It talks to Herdr’s Unix sockets, folds every live session into a glanceable count, and jumps you back to a pane that already exists.

Requires Herdr 0.8+ and macOS 13+. The app is an `LSUIElement` — it never appears in the Dock.
:::

## FAQ

**What is herdr-bar?**
A macOS menu-bar extra for [Herdr](https://herdr.dev/). It does not start Herdr. It discovers `herdr.sock`, shows Done / Working counts, and Option-click focuses the highest-priority agent.

**How do I install it?**
Download a tagged `HerdrBar-*-macos.zip` from [GitHub Releases](https://github.com/openalon-org/herdr-bar/releases), or `./scripts/install.sh` from source. The zip is ad-hoc signed — first launch may need right-click → Open. Details: [Install](/guide/installation).

**Does it create new panes?**
No. Focus is `agent.focus` plus raising the terminal that already hosts that session’s TUI. See [Usage](/guide/usage) and [Architecture](/guide/architecture).
