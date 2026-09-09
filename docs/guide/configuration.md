---
outline: false
---

# Configuration

Preferences live in `~/.config/herdr/herdr-bar.json`, next to Herdr’s own config. The gear and a hand-edited file are the same document; the process watches the directory and hot-reloads colors.

## Config file {#file}

```json
{
  "colors": {
    "blocked": "#5F87FF",
    "done": "#00D75F",
    "working": "#CF7650",
    "unknown": "#C7A35A",
    "idle": "#888888"
  },
  "hideIdle": false,
  "hotkey": {
    "keyCode": 49,
    "command": true,
    "shift": true
  }
}
```

Rules:

- Fields may be missing. Missing = product default.
- `hideIdle` defaults to `true`. When true it is **omitted from disk**, so a colors-only file stays colors-only.
- `hotkey` defaults to unbound. `keyCode` is a Carbon hardware virtual key (`kVK_*`); modifiers are Cocoa-style booleans.
- An empty root object deletes the file.

## Status colors {#colors}

Defaults match [Claude Code](https://code.claude.com/docs) terminal tab-status. Working is the exception: CLI spinner terracotta `#CF7650`, still readable on a light popover.

| Status | Default | Meaning |
|---|---|---|
| <span class="status-swatch blocked"></span>blocked | `#5F87FF` | Claude `waiting` — waiting on you |
| <span class="status-swatch done"></span>done | `#00D75F` | Turn finished |
| <span class="status-swatch working"></span>working | `#CF7650` | CLI spinner terracotta (`Bunning…` on light terminals) |
| <span class="status-swatch unknown"></span>unknown | `#C7A35A` | Unreadable state |
| <span class="status-swatch idle"></span>idle | `#888888` | Claude idle `statusColor` |

Click a well in the gear to override one status. Restoring the default drops the override. **Reset** appears in the header when anything is overridden. Settings labels it **Custom** — no hex captions.

Wells are SwiftUI `ColorPicker` (macOS capsule). Opening the panel switches the popover to `.applicationDefined` so `NSColorPanel` does not dismiss a transient popover.

## Notification mode {#hide-idle}

`hideIdle` (default true) is a dashboard filter. It does **not** affect the menu bar (idle never draws there):

- A group still has non-idle rows → hide idle rows; the header may show how many are hidden
- A group is idle-only → drop the whole group

Toggle with the header eye. To show parked agents by default, set `hideIdle` to `false`.

## Global hotkey {#hotkey}

Gear → **Keyboard → Open dashboard**. Click the well, hold ⌘ / ⌥ / ⌃ plus a key. Carbon `RegisterEventHotKey` — no Accessibility prompt.

A conflict turns the footer into *That shortcut is already taken*. **Clear** unbinds it.

JSON example (⇧⌘Space, `kVK_Space` = 49):

```json
{
  "hotkey": {
    "keyCode": 49,
    "command": true,
    "shift": true
  }
}
```

The same group lists in-window shortcuts: ↑↓ walk tasks, ←→ walk sessions / folders, ↩ focuses.

## Updates {#updates}

Gear → **About**. The extra reads `CFBundleShortVersionString` and compares it to GitHub `/repos/openalon-org/herdr-bar/releases/latest`. There is no Sparkle install path — an available update opens the release page. Local `swift run` / unpackaged binaries show `dev`.
