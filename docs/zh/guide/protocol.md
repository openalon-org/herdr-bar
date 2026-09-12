---
outline: false
description: Unix socket 上的 newline JSON-RPC：agent.list、agent.focus 与 events.subscribe。
---

# 协议

传输是 **Unix domain socket 上的 newline-delimited JSON-RPC**。Herdr 在一次响应后关掉请求 socket。订阅 socket 保持打开，并放出没有 `id` 的事件。

## 传输 {#transport}

```json
{"id":"herdr-bar:1710000000000:agent.list","method":"agent.list","params":{}}
```

```json
{"id":"herdr-bar:1710000000000:agent.list","result":{"type":"agent_list","agents":[...]}}
```

实现细节（`HerdrClient`）：

- 连接超时默认 3s
- 每条消息一行 JSON + `\n`
- `id` 形如 `herdr-bar:<epoch-ms>:<method>`
- `error.message` 会冒泡成 `HerdrClient.ClientError.herdr`

`tools/demo-server.py` 使用同一套协议，用来拍产品演示。

## 方法 {#methods}

| 方法 | Socket | 作用 |
|---|---|---|
| `agent.list` | 一次性 | 该 session 当前 agent |
| `agent.focus` | 一次性 | 把 `params.target` 标成已看（名字或 pane id） |
| `tab.focus` | 一次性 | 把已 attach 的 TUI 切到 `params.tab_id`（Herdr 0.9+） |
| `pane.focus` | 一次性 | 在该 tab 里选 `params.pane_id` |
| `events.subscribe` | 长连接 | 登记失效订阅 |

`agent.list` 行映射到 `Agent`（snake_case JSON → Swift）：

| JSON | 字段 |
|---|---|
| `pane_id` | 身份。空则丢掉该行 |
| `tab_id` | 该 pane 所在 tab，给 `tab.focus` 用 |
| `workspace_id` | 该 pane 所在 workspace |
| `name` | 聚焦目标，优先于 pane id |
| `display_agent` / `agent` | 标签回退 |
| `agent_status` | 规范化成五种状态 |
| `state_change_seq` | 同优先级时的注意力排序键 |
| `cwd` / `foreground_cwd` | folder 与 git 根 |
| `terminal_title_stripped` / `terminal_title` | 标签回退 |
| `agent_session.value` | Claude 对话 UUID |

Herdr **不**给 git 分支或模型。那些由 `GitBranchCache` 和 `SessionTimeCache` 补上。耗时和 token 不进 extra，也不进仪表盘。

## 事件 {#events}

订阅集合（`HerdrLogic.subscriptions`）：

```json
[
  { "type": "pane.agent_detected" },
  { "type": "pane.closed" },
  { "type": "pane.exited" },
  { "type": "pane.moved" },
  { "type": "pane.agent_status_changed", "pane_id": "w2:p7" }
]
```

`pane.agent_status_changed` 按当前快照里每个非空 `pane_id` 各登一条。pane 集合变了（`paneKey` 排序拼接）就重建订阅。

事件 payload **不是**新状态。客户端把它当失效：丢掉快照，再 `agent.list`。这样各 agent 运行时特有的解释留在 Herdr 里，菜单栏不会和 TUI 漂成两套真相。

订阅出错：关掉 socket，若 session 仍显示在线，1s 后重建。命令刷新失败：清空该 session 的 agent，标 offline，1s → 30s 退避。

## 身份 {#identity}

跨 session 唯一键：

```text
(sessionName, pane_id)  →  "work::w2:p7"
```

Socket 路径（`HerdrLogic.socketPath`，也是 `Herdr.js` 行为对照）：

```text
default  →  ~/.config/herdr/herdr.sock
<name>   →  ~/.config/herdr/sessions/<name>/herdr.sock
~/...    →  相对于 $HOME 展开
```

`HERDR_SOCKET` 绕过发现，固定单个 `demo` session——开发期和 `--demo` fixture 用。
