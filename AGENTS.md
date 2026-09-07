# AGENTS.md

## Project overview

herdr-bar is a macOS menu-bar companion for Herdr. It renders normalized coding-agent states, opens a dashboard, and focuses existing agent panes.

## Invariants

- Keep status updates event-driven through `events.subscribe`; never poll Herdr on a timer.
- Treat events as invalidation signals and refresh with `agent.list`.
- Clicking may focus an existing pane with `agent.focus`; it must never create a terminal, window, pane, tab, or agent.
- Priority is `blocked`, `done`, `working`, `unknown`, then `idle`; newest `state_change_seq` wins ties.
- Keep harness-specific state interpretation inside Herdr.
- Host-app raising is optional and isolated in `FocusRaiser`. Raise the TUI client (`herdr` / `herdr session attach <name>`), never `herdr server` on the listening socket.
- Discover every live session (`~/.config/herdr/herdr.sock` and `sessions/*/herdr.sock`) and aggregate counts. Agent identity is `(sessionName, pane_id)`.
- Do not post extra OS notifications; Herdr already owns `[ui.toast]`.
- Status colors default to Claude Code's tab-status palette except working, which uses the CLI spinner terracotta (`#CF7650`) so it stays readable on a light popover. Change them from the dashboard gear; overrides live in `~/.config/herdr/herdr-bar.json` (`colors.blocked|done|working|unknown|idle`). The agent list stays a jump list.
- Dashboard defaults to notification mode: hide idle rows in mixed groups and drop idle-only groups. The header eye toggles this (`hideIdle` in the same JSON; default true, omitted when true).
- Dashboard hierarchy is session (scope chips) → folder (section headers) → status (row color). Do not add a third chip row. All uses the same folder grouping as a single session; never sort by session.
- Idle-only folders sort by the newest conversation time in that space (`~/.claude/projects/.../<uuid>.jsonl` mtime via `agent_session.value`). Same-status rows inside a folder also use that time (newest first), then pane number. A just-finished Done that becomes Idle stays above older idle panes. Do not use `state_change_seq` to order across sessions in All.
- Working and Done rows read model and turn times from that same jsonl (not Claude's statusline stdin). Done freezes `end_turn −` latest **human** user turn (`tool_result` is also `type=user` and must not start a prompt). Working ticks from the latest jsonl write (human, `tool_result`, or assistant) so a long tool loop matches CLI `Churning (17s)` instead of the whole prompt. If Herdr flips to Working before the new user line is on disk, pin the first-seen Working instant so the clock does not keep accumulating from the previous prompt. Idle does not show a duration. Motion is Claude Code 2.1.263's Darwin spinner (`·✢✳✶✻✽` ping-pong, `floor(ms/120)%12`) on the row and the menu-bar working chip. Idle / done / blocked / unknown park on `✻` in the same 14pt slot — no 4px status bar. A 1s timer may re-read jsonl while any agent is Working; it must not poll `agent.list`.
- Menu-bar extra is a glance, not inventory. Product line, in order:
  1. Idle never appears there (the dashboard eye still shows parked agents).
  2. Done and working are the skeleton while Herdr is online — zero counts keep the slot at full color. Halo and spin only when the count is above zero.
  3. Blocked / unknown join only when they need you. Width hugs that cluster (`+ 4pt inset`); it jumps for digit rollover or an interrupt, not because a skeleton chip vanished.
  4. Say each fact once: `0` already means none — do not dim. Neighbor gaps and the press-highlight capsule are `NSStatusBarButton`'s; `StatusItemView` stays transparent (`isOpaque = false`, no `super.draw`) so Tahoe glass shows through.
  Offline stays the 22pt dot. Optical spacing (halo leading pad, shared mark-to-digit gap), not equal box gaps.
- Dashboard settings can bind a Carbon global hotkey (`hotkey` in herdr-bar.json) that toggles the popover. No extra Accessibility prompt. While the dashboard is open, up/down walk the visible task list and left/right cycle session chips (or folder groups when only one session is online). Enter focuses the highlighted row. Settings is two inset groups (Status colors, Keyboard); the Keyboard group lists those in-window shortcuts next to the opener.
- Agent list and settings scroll like a Chrome page: overlay thumb, momentum, hard stop at the edges (`verticalScrollElasticity = .none` on the SwiftUI `NSScrollView`). Do not rubber-band. Keyboard arrows reveal the highlight only if it is off-screen; a mouse fling must not be yanked back to the selected row.
- The published tree is de-personalized. Tests, comments, fixtures, and docs must not contain a real home directory, login, machine hostname, local project path (`/Users/<you>/…`, `/home/<you>/…`, `workspace2/`), or a real session / repo name. Named-session examples are `default` plus a generic `work`. Folder fixtures are synthetic (`alpha`, `notes`, `beta`, `gamma`, `app.local`). Use roots `/Users/me`, `/home/user`, `~/…`. A test that only runs on one laptop does not belong in git; rewrite it against temp dirs or those fixtures. Scan before commit: `git grep -nE '/Users/|/home/|eden|client\\.new' -- . ':!package-lock.json'`.

## Repository map

- `Sources/HerdrCore` — protocol, discovery, aggregation, focus raising.
- `Sources/MacBar` — `NSStatusItem`, dashboard popover.
- `Herdr.js` / `tests/herdr.test.mjs` — behavior oracle kept during the port.
- `tools/demo-server.py` — newline JSON fixture.
- `scripts/dev-run.sh` / `scripts/package-app.sh` / `scripts/install.sh` / `scripts/reload.sh` — throwaway run, pack a `.app` (CI zips it), install into `~/Applications/HerdrBar.app`, and test-then-replace the live extra. Source is not the running extra. Push a `v*` tag for the unsigned GitHub Release zip (`.github/workflows/release.yml`). No Developer ID / notarization in this tree.
- `.agents/skills/` — project skills (body). `.claude/skills` is a symlink to that folder so Claude Code discovers them. `test-reload` runs `scripts/reload.sh` after extra / HerdrCore changes so the menu bar matches the tree.
- `docs/` — VitePress site (GitHub Pages). English at the root, Simplified Chinese under `docs/zh/`. Preview with `npm run docs:dev`.
- `.github/ISSUE_TEMPLATE/` / `.github/pull_request_template.md` / `CONTRIBUTING.md` / `SECURITY.md` — community files. Behavior still lives in this document.

## Validation

```bash
node --test tests/herdr.test.mjs
swift test
```

Live: run `scripts/dev-run.sh` against default+work, or `scripts/dev-run.sh --demo` against the fixture. After extra / core changes the user should see, `scripts/reload.sh` (tests + install + restart). Do not assume `swift test` updated `HerdrBar.app`.
