---
outline: false
---

# Protocol

Transport is **newline-delimited JSON-RPC over a Unix domain socket**. Herdr closes a request socket after one response. Subscribe sockets stay open and emit events with no `id`.

## Transport {#transport}

```json
{"id":"herdr-bar:1710000000000:agent.list","method":"agent.list","params":{}}
```

```json
{"id":"herdr-bar:1710000000000:agent.list","result":{"type":"agent_list","agents":[...]}}
```

`HerdrClient` details:

- Connect timeout defaults to 3s
- One JSON object per line, then `\n`
- `id` looks like `herdr-bar:<epoch-ms>:<method>`
- `error.message` surfaces as `HerdrClient.ClientError.herdr`

`tools/demo-server.py` speaks the same protocol so you can film the product.

## Methods {#methods}

| Method | Socket | Role |
|---|---|---|
| `agent.list` | one-shot | agents in that session |
| `agent.focus` | one-shot | focus `params.target` (name or pane id) |
| `events.subscribe` | long-lived | register invalidation subscriptions |

`agent.list` rows map onto `Agent` (snake_case JSON → Swift):

| JSON | Field |
|---|---|
| `pane_id` | identity; empty rows are dropped |
| `name` | focus target, preferred over pane id |
| `display_agent` / `agent` | label fallback |
| `agent_status` | normalized to the five states |
| `state_change_seq` | attention tie-break |
| `cwd` / `foreground_cwd` | folder and git root |
| `terminal_title_stripped` / `terminal_title` | label fallback |
| `agent_session.value` | Claude conversation UUID |

Herdr does **not** send git branch or model. `GitBranchCache` and `SessionTimeCache` fill those in. Elapsed time and tokens stay out of the extra and the dashboard.

## Events {#events}

Subscription set (`HerdrLogic.subscriptions`):

```json
[
  { "type": "pane.agent_detected" },
  { "type": "pane.closed" },
  { "type": "pane.exited" },
  { "type": "pane.moved" },
  { "type": "pane.agent_status_changed", "pane_id": "w2:p7" }
]
```

One `pane.agent_status_changed` per non-empty `pane_id` in the current snapshot. When the pane set changes (`paneKey` sorted join), the subscription is rebuilt.

The event payload is **not** the new state. The client treats it as invalidation: drop the snapshot, then `agent.list`. Harness-specific interpretation stays in Herdr, so the extra and the TUI cannot drift into two truths.

Subscribe error: close the socket; if the session still looks online, rebuild after 1s. Command refresh failure: clear that session’s agents, mark offline, back off 1s → 30s.

## Identity {#identity}

Unique across sessions:

```text
(sessionName, pane_id)  →  "work::w2:p7"
```

Socket paths (`HerdrLogic.socketPath`, also the `Herdr.js` oracle):

```text
default  →  ~/.config/herdr/herdr.sock
<name>   →  ~/.config/herdr/sessions/<name>/herdr.sock
~/...    →  expanded against $HOME
```

`HERDR_SOCKET` skips discovery and pins a single `demo` session — for development and the `--demo` fixture.
