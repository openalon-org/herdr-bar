---
outline: false
---

# 架构

herdr-bar 是两个 Swift target：`HerdrCore`（协议、发现、聚合、举起宿主）和 `MacBar`（`NSStatusItem` + SwiftUI popover）。`Herdr.js` 仍是状态顺序、计数、socket 路径的行为对照。

## 分层 {#layers}

<div class="diagram">
  <p class="diagram-title">从 socket 到菜单栏</p>
  <div class="stack">
    <div class="layer l1">
      <div class="layer-num">①</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">MacBar</div>
          <div class="layer-desc">菜单栏一览与仪表盘 popover</div>
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
      <div class="layer-num">②</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">聚合</div>
          <div class="layer-desc">每个 live session 一份快照，agent 打上 sessionName</div>
        </div>
        <div class="layer-items">
          <span class="layer-item">SessionManager</span>
          <span class="layer-item">AgentAggregator</span>
          <span class="layer-item">HerdrLogic</span>
        </div>
      </div>
    </div>
    <div class="layer l3">
      <div class="layer-num">③</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">每 session 监视</div>
          <div class="layer-desc">命令 socket + 长订阅；事件只失效，不当真相</div>
        </div>
        <div class="layer-items">
          <span class="layer-item">SessionWatcher</span>
          <span class="layer-item">HerdrClient</span>
          <span class="layer-item">events.subscribe</span>
        </div>
      </div>
    </div>
    <div class="layer l4">
      <div class="layer-num">④</div>
      <div class="layer-body">
        <div>
          <div class="layer-name">本机富化</div>
          <div class="layer-desc">Herdr 没有的字段：分支、模型、对话时间</div>
        </div>
        <div class="layer-items">
          <span class="layer-item">GitBranchCache</span>
          <span class="layer-item">SessionTimeCache</span>
          <span class="layer-item">FocusRaiser</span>
          <span class="layer-item">UpdateCheck</span>
        </div>
      </div>
    </div>
  </div>
</div>

`MacBarApp` 把激活策略设成 `.accessory`。没有 Dock 图标，没有主窗口。

## 数据流 {#data-flow}

<div class="diagram">
  <p class="diagram-title">事件是失效信号，列表才是真相</p>
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

每个发现到的 socket 得到一个 `SessionWatcher`：

- **命令 socket**（用完即关）：`agent.list`、`agent.focus`
- **订阅 socket**（长连接）：`events.subscribe`。无 `id` 的行触发刷新

刷新路径：`agent.list` → `GitBranchCache.enrich`（读 `.git/HEAD`，不 spawn `git`）→ `SessionTimeCache.enrich`（Claude jsonl）→ `SessionSnapshot`。失败则指数退避重连（1s → 30s）。

`AgentAggregator` 只合并 **online** 快照。session 掉线，它的 agent 从总列表消失。

## 发现与聚合 {#discovery}

`SessionDiscovery` 扫描：

| Session | Socket |
|---|---|
| `default` | `~/.config/herdr/herdr.sock` |
| named（如 `work`） | `~/.config/herdr/sessions/&lt;name&gt;/herdr.sock` |
| 固定 `HERDR_SOCKET` | 该路径，名字叫 `demo` |

`SessionManager` 监视 `~/.config/herdr` 和 `sessions/`（`DispatchSource` 文件事件）。这是 **文件系统失效**，不是 `agent.list` 轮询。配置目录还不存在时，用 2s 退避直到出现。

Agent 身份是 `(sessionName, pane_id)`。`Agent.id` 渲染成 `sessionName::paneId`。同名 pane 可以同时活在 default 和 eden 里。

## 聚焦宿主 {#focus-raiser}

`FocusRaiser` 和协议逻辑隔离。点击路径是：

1. `raiseHost` — 先动窗口，不要等 RPC
2. `agent.focus` — 告诉 Herdr 选哪个 pane

它找的是 **TUI 客户端**：

- `herdr`（无参数）= default TUI
- `herdr session attach <name>` = named session
- **不是** `herdr server`（通常 ppid 为 1，握着监听 socket）

然后沿父进程走到 `activationPolicy == .regular` 的 GUI 祖先（跳过 Xcode 和 herdr-bar 自己），`unhide` + `activate`。macOS 14+ 先 `yieldActivation`。宿主 PID 缓存在点击路径之外，用 `sysctl`（`KERN_PROC` / `KERN_PROCARGS2`），不 spawn `lsof` / `ps`。
