---
outline: false
---

# 不变量

这些约束就是产品。改行为前先读 [`AGENTS.md`](https://github.com/openalon-org/herdr-bar/blob/main/AGENTS.md)。测试（Swift + `Herdr.js` 行为对照）就是为了锁住它们。

## 更新

- 经 `events.subscribe` **事件驱动**。从不按定时器轮询 Herdr。
- 事件是 **失效信号**。刷新永远走 `agent.list`。
- 发现新 socket 靠文件系统监视（`~/.config/herdr`），不是 agent 轮询。配置目录还不存在时允许退避重试。

## 聚焦

- 点击可以 `agent.focus` 已有 pane。
- **禁止**创建 terminal、window、pane、tab 或 agent。
- 举起宿主是可选的，隔离在 `FocusRaiser`。
- 举起 TUI 客户端（`herdr` / `herdr session attach <name>`），**不要**举 `herdr server`。

## 优先级与身份

- 顺序：`blocked`，`done`，`working`，`unknown`，然后 `idle`。
- 同优先级：最新 `state_change_seq` 赢。
- Agent 身份：`(sessionName, pane_id)`。
- 发现每一个 live session 并聚合计数。

## 展示

- 菜单栏是一览，不是完整清单。Idle 不上栏。
- 在线时 Done / Working 常驻（含 0，全色）。光环和 spinner 只在计数 > 0。Blocked / Unknown 只在计数 > 0 时插入。
- 宽度贴着这组芯片。数字进位或 Blocked / Unknown 插入才变宽，不因为骨架芯片消失而跳。
- 一个意思只说一遍：`0` 已经是没有，不要再淡。邻接缝和按住胶囊是系统的。extra 只画点和数字，不 `super.draw`、不给自定义 view 铺底。
- 离线保持 22pt 点。
- 进 git 的树要去隐私。测试、注释、fixture、文档里不要出现真实家目录、登录名、主机名、本机工程路径，或真实的 session / 仓库名。named session 示例只用 `default` 加一个通用的 `work`。folder fixture 用合成名（`alpha`、`notes`、`beta`）。路径只用 `/Users/me`、`/home/user`、`~/…`。只在某台电脑上才过的测试不要提交。
- 仪表盘默认通知模式（藏 idle）。眼睛切换；`hideIdle` 默认 true。
- 层级：session（chip）→ folder（header）→ status（行颜色）。不要加第三排 chip。
- `All` 使用与单 session 相同的 folder 分组；从不按 session 排序。
- 纯 idle folder、以及同状态行，按对话时间排，不用跨 session 的 `state_change_seq`。

## 颜色与通知

- 默认颜色 = Claude Code tab-status；working = spinner 陶土 `#CF7650`。
- 覆盖写在 `~/.config/herdr/herdr-bar.json`。
- agent 列表保持跳转列表；颜色进齿轮。
- 不要再发 OS 通知。Herdr 已经有 `[ui.toast]`。

## 解释边界

- 各 agent 运行时特有的状态解释留在 Herdr。
- Git 分支和模型是本机富化，不是 Herdr 字段。不画耗时、不画 token。禁止定时轮询 jsonl 或 `agent.list`。
- `Herdr.js` 仍是状态顺序、计数、socket 路径的行为对照。行为变化应带上最窄有用的测试，并在影响安装 / 设置 / 交互时更新 README 与本站。
