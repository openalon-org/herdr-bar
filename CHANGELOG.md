# Changelog

All notable changes to herdr-bar are documented here.

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
