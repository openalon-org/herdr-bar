---
outline: false
---

# Architecture

Two Swift targets: `HerdrCore` (protocol, discovery, aggregation, raising the host) and `MacBar` (`NSStatusItem` + SwiftUI popover). `Herdr.js` is still the behavior oracle for status order, counts, and socket paths.

## Layers {#layers}

<div class="diagram">
  <p class="diagram-title">From socket to menu bar</p>
  <div class="stack">
    <div class="layer l1">
      <div class="layer-num">1</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">MacBar</div>
          <div class="layer-desc">Menu-bar glance and dashboard popover</div>
        </div>
        <div class="layer-items">
          <span class="layer-item">StatusItemController</span>
          <span class="layer-item">StatusItemView</span>
          <span class="layer-item">DashboardView</span>
          <span class="layer-item">SettingsView</span>
          <span class="layer-item">HotkeyCenter</span>
        </div>
      </div>
    </div>
    <div class="layer l2">
      <div class="layer-num">2</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">Aggregation</div>
          <div class="layer-desc">One snapshot per live session; agents tagged with sessionName</div>
        </div>
        <div class="layer-items">
          <span class="layer-item">SessionManager</span>
          <span class="layer-item">AgentAggregator</span>
          <span class="layer-item">HerdrLogic</span>
        </div>
      </div>
    </div>
    <div class="layer l3">
      <div class="layer-num">3</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">Per-session watch</div>
          <div class="layer-desc">Command socket + long subscribe; events invalidate, they are not truth</div>
        </div>
        <div class="layer-items">
          <span class="layer-item">SessionWatcher</span>
          <span class="layer-item">HerdrClient</span>
          <span class="layer-item">events.subscribe</span>
        </div>
      </div>
    </div>
    <div class="layer l4">
      <div class="layer-num">4</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">Local enrichment</div>
          <div class="layer-desc">Fields Herdr does not send: branch, model, conversation time</div>
        </div>
        <div class="layer-items">
          <span class="layer-item">GitBranchCache</span>
          <span class="layer-item">SessionTimeCache</span>
          <span class="layer-item">FocusRaiser</span>
        </div>
      </div>
    </div>
  </div>
</div>

`MacBarApp` sets the activation policy to `.accessory`. No Dock icon, no main window.

## Data flow {#data-flow}

<div class="diagram">
  <p class="diagram-title">Events invalidate; the list is truth</p>
  <div class="flow">
    <span class="flow-box">Unix socket</span>
    <span class="flow-arrow">→</span>
    <span class="flow-box accent">events.subscribe</span>
    <span class="flow-arrow">→</span>
    <span class="flow-box">invalidate</span>
    <span class="flow-arrow">→</span>
    <span class="flow-box cool">agent.list</span>
    <span class="flow-arrow">→</span>
    <span class="flow-box">enrich</span>
    <span class="flow-arrow">→</span>
    <span class="flow-box">Aggregator</span>
    <span class="flow-arrow">→</span>
    <span class="flow-box">menu bar + dashboard</span>
  </div>
</div>

Each discovered socket gets a `SessionWatcher`:

- **Command socket** (closed after one response): `agent.list`, `agent.focus`
- **Subscribe socket** (long-lived): `events.subscribe`. Lines without `id` trigger a refresh

Refresh path: `agent.list` → `GitBranchCache.enrich` (read `.git/HEAD`, never spawn `git`) → `SessionTimeCache.enrich` (Claude jsonl) → `SessionSnapshot`. Failure reconnects with exponential backoff (1s → 30s).

`AgentAggregator` merges **online** snapshots only. When a session drops, its agents leave the combined list.

## Discovery {#discovery}

`SessionDiscovery` scans:

| Session | Socket |
|---|---|
| `default` | `~/.config/herdr/herdr.sock` |
| named (e.g. `work`) | `~/.config/herdr/sessions/&lt;name&gt;/herdr.sock` |
| pinned `HERDR_SOCKET` | that path, named `demo` |

`SessionManager` watches `~/.config/herdr` and `sessions/` (`DispatchSource` file events). That is **filesystem invalidation**, not `agent.list` polling. If the config directory does not exist yet, retry with a 2s backoff until it does.

Agent identity is `(sessionName, pane_id)`. `Agent.id` renders as `sessionName::paneId`. The same pane token can live in default and work at once.

## Focus raiser {#focus-raiser}

`FocusRaiser` is isolated from protocol logic. The click path is:

1. `raiseHost` — move the window first; do not wait for RPC
2. `agent.focus` — tell Herdr which pane to select

It looks for the **TUI client**:

- `herdr` (no args) = default TUI
- `herdr session attach <name>` = named session
- **not** `herdr server` (typically ppid 1, holding the listening socket)

Then it walks parents to a GUI ancestor with `activationPolicy == .regular` (skipping Xcode and herdr-bar itself), `unhide` + `activate`. On macOS 14+ it `yieldActivation` first. Host PIDs are cached off the click path via `sysctl` (`KERN_PROC` / `KERN_PROCARGS2`) — no `lsof` / `ps` spawn.
