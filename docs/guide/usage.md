---
outline: false
---

# Usage

Two layers: a **menu-bar glance** (counts) and a **dashboard** (jump list). The extra is not a full inventory of every agent.

## Menu bar {#menubar}

<div class="diagram">
  <p class="diagram-title">Menu-bar glance (Done / Working stay put)</p>
  <div class="chip-row">
    <span class="menubar-chip"><span class="dot" style="background:#00D75F"></span>0</span>
    <span class="menubar-chip"><span class="dot" style="background:#CF7650"></span>✻ 2</span>
    <span style="font-size:12px;color:var(--vp-c-text-3)">idle never draws · blocked / unknown insert when they need you · offline = 22pt dot</span>
  </div>
</div>

| Gesture | Action |
|---|---|
| Left-click | Open the dashboard |
| Option-click | Focus the highest-priority agent |
| Right-click | Refresh with `agent.list` now |
| Global hotkey | Toggle the dashboard (bound in the gear) |

While online, Done / Working stay on the extra (including zeros). Width hugs the chips; the cluster is centered. Blocked / Unknown or wider digits stretch the extra. The working chip uses Claude Code’s Darwin spinner (`·✢✳✶✻✽` ping-pong, 120ms). Blocked / done / unknown breathe a halo when the count is above zero — never a hard blink. The press-highlight capsule is the system’s; at rest the extra does not paint a second one.

::: tip Why idle stays off the extra
The menu bar is a glance. Parked agents still exist — open the eye in the dashboard header.
:::

## Dashboard {#dashboard}

The popover is a fixed **372 × 480**. Hiding idle must not shrink the window so it cannot grow back (`NSPopover` remembers the last height).

Three layers only — no third chip row:

1. **Session** — scope chips: `All` / `default` / `work` (only when two or more sessions are online). Chip body filters. Named session chips (not All) keep a trailing arrow that focuses the first row of that herdr session, including idle.
2. **Folder** — section headers (last path component of `foreground_cwd` / `cwd`)
3. **Status** — row color and priority

Header:

- **Mark** — quiet hierarchical `cpu` SF Symbol. Finder / Login Items / About use the same gray `cpu` on a light tile.
- **Eye** — notification mode. On by default: hide idle rows in mixed groups, drop idle-only groups.
- **Gear** — General (open at login), status colors, keyboard (system-wide opener plus in-window shortcuts), and About (app icon + version + Check for Updates against GitHub Releases).

Rows:

- Title from `name` / `display_agent` / `terminal_title` / `agent` / `pane_id`
- Subtitle: `session · folder · branch · model`
- Working rows: Darwin spinner and short model name
- Status sits on the right of the row. No elapsed time, no token count — those live in the CLI footer, not herdr-bar

Click a row = `agent.focus` that pane, then raise the host terminal.

## Keyboard {#keyboard}

<div class="diagram">
  <p class="diagram-title">In-window vs system-wide</p>
  <div class="kbd-row">
    <span class="kbd-pill"><kbd>↑</kbd><kbd>↓</kbd> tasks in the current filter</span>
    <span class="kbd-pill"><kbd>←</kbd><kbd>→</kbd> session chips; folders when only one session is online</span>
    <span class="kbd-pill"><kbd>↩</kbd> focus the highlight (priority agent if none)</span>
    <span class="kbd-pill"><kbd>Esc</kbd> close settings, then the dashboard</span>
  </div>
</div>

The opener is a **system-wide** Carbon hotkey — no Accessibility prompt. Arrows and Return only work while the dashboard is open.

## Focus {#focus}

Focus is always:

1. `agent.focus` on the session that owns the pane
2. Raise the GUI terminal already running that session’s TUI (cmux / Otty / Ghostty / …)

It **never**:

- Creates a terminal / window / pane / tab / agent
- Activates `herdr server` (the process on the listening socket)
- Posts another OS notification (Herdr already owns `[ui.toast]`)

The target is `agent.name`, or `pane_id` when the name is empty.
