# Changelog

All notable changes to herdr-bar are documented here.

## [0.1.2] - 2026-09-10

### Added
- Desktop WidgetKit gallery widget: a read-only All-scope snapshot of the dashboard list. Tap a row to focus that agent in the extra (`herdr-bar://focus`). Extra must be running (Open at login).
- App icon shared by Finder, Login Items, and About (light tile, label-gray cpu).
- Open at login toggle in dashboard settings (`SMAppService`, the system Login Items list).
- Check for Updates on the About row: compares this build to GitHub Releases and opens the latest tag. Still does not install itself (ad-hoc zip, no Sparkle).
- Jump arrow on named session chips (not All). Chip body still filters; the arrow focuses that session's first list row, including idle.

### Changed
- Settings layout: About is one row (icon + name open the repo; Check for Updates on the trailing edge). Color wells move last so login, keyboard, and About fit the first screen.

### Thanks to 1 contributor!

- [@openalon](https://github.com/openalon)

## [0.1.1] - 2026-09-08

### Changed
- Drop elapsed time, token counts, and pane chips from dashboard rows. jsonl is not Claude statusline stdin, so those numbers never matched the CLI footer; titles already identify the row. Keep the short model name on Working / Done and jsonl mtime for idle sort.

### Thanks to 1 contributor!

- [@openalon](https://github.com/openalon)

## [0.1.0] - 2026-09-08

### Added
- Menu-bar extra that discovers every live Herdr session (`default` and named) and folds agents into one glance
- Event-driven updates: `events.subscribe` invalidates, `agent.list` refreshes — never poll Herdr on a timer
- Dashboard grouped session → folder → status, with notification mode that hides idle
- Option-click jumps to the highest-priority agent (blocked, done, working, unknown, idle)
- Click a row to `agent.focus` and raise the terminal already hosting that session — never create a pane
- Status colors default to Claude Code’s tab palette; override them from the gear
- Global hotkey to toggle the dashboard, plus in-window arrow and Return navigation
- Working spinner matches Claude Code’s Darwin `·✢✳✶✻✽` ping-pong

### Thanks to 1 contributor!

- [@openalon](https://github.com/openalon)
