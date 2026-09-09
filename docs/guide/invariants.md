---
outline: false
---

# Invariants

These constraints *are* the product. Read [`AGENTS.md`](https://github.com/openalon-org/herdr-bar/blob/main/AGENTS.md) before changing behavior. Tests (Swift plus the `Herdr.js` behavior oracle) lock them in.

## Updates

- **Event-driven** through `events.subscribe`. Never poll Herdr on a timer.
- Events are **invalidation**. Refresh always goes through `agent.list`.
- New sockets are discovered by watching the filesystem (`~/.config/herdr`), not by polling agents. Backoff is allowed until the config directory exists.

## Focus

- A click may `agent.focus` an existing pane.
- **Never** create a terminal, window, pane, tab, or agent.
- Raising the host is optional and isolated in `FocusRaiser`.
- Raise the TUI client (`herdr` / `herdr session attach <name>`), **never** `herdr server`.

## Priority and identity

- Order: `blocked`, `done`, `working`, `unknown`, then `idle`.
- Ties: newest `state_change_seq` wins.
- Agent identity: `(sessionName, pane_id)`.
- Discover every live session and aggregate counts.

## Presentation

- The menu bar is a glance, not a full inventory. Idle never appears there.
- While online, Done / Working stay put (including 0, full color). Halo and spinner only when the count is above zero. Blocked / Unknown insert only when their count is above zero.
- Width hugs that cluster. It grows for digit rollover or a Blocked / Unknown insert, not because a skeleton chip vanished.
- Say each fact once: `0` already means none — do not dim. Neighbor seams and the press capsule are the system’s. The extra draws dots and digits only — no `super.draw`, no fill on the custom view.
- Offline stays a 22pt dot.
- The published tree is de-personalized. Tests, comments, fixtures, and docs must not contain a real home directory, login, hostname, local project path, or a real session / repo name. Named-session examples are `default` plus a generic `work`. Folder fixtures are synthetic (`alpha`, `notes`, `beta`). Use `/Users/me`, `/home/user`, `~/…`. A test that only passes on one laptop does not belong in git.
- Dashboard defaults to notification mode (hide idle). The eye toggles it; `hideIdle` defaults true.
- Hierarchy: session (chips) → folder (headers) → status (row color). Do not add a third chip row.
- `All` uses the same folder grouping as a single session; never sort by session.
- Idle-only folders, and same-status rows, sort by conversation time — not cross-session `state_change_seq`.

## Colors and notifications

- Default colors = Claude Code tab-status; working = spinner terracotta `#CF7650`.
- Overrides live in `~/.config/herdr/herdr-bar.json`.
- The agent list stays a jump list; colors live in the gear.
- Gear → About may check GitHub Releases. It must not install or relaunch (no Sparkle; the zip is ad-hoc).
- Do not post extra OS notifications. Herdr already owns `[ui.toast]`.

## Interpretation boundary

- Harness-specific status interpretation stays in Herdr.
- Git branch and model are local enrichment, not Herdr fields. Do not show elapsed time or tokens. Do not timer-poll jsonl or `agent.list`.
- `Herdr.js` remains the oracle for status order, counts, and socket paths. Behavior changes should ship the narrowest useful test, and update the README plus this site when they affect install, settings, or interactions.
