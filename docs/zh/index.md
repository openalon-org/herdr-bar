---
layout: home

hero:
  name: herdr-bar
  text: 菜单栏上的 Herdr 伴侣
  tagline: 一眼看到每个 coding agent。跳到最需要你的那个。不轮询，不新建 pane。
  image:
    src: /herdr-bar-icon.svg
    alt: herdr-bar
  actions:
    - theme: brand
      text: 开始安装
      link: /zh/guide/installation
    - theme: alt
      text: 更新日志
      link: /zh/changelog

features:
  - icon: 👁
    title: 菜单栏一览
    details: Done / Working 常驻菜单栏。Blocked / Unknown 有人时才出现。Idle 不占菜单栏，藏在仪表盘的眼睛后面。
    link: /zh/guide/usage
  - icon: ⚡
    title: 事件驱动
    details: 通过 Herdr 的 events.subscribe 失效快照，再用 agent.list 刷新。从不按定时器轮询。
    link: /zh/guide/protocol
  - icon: 🎯
    title: 优先级聚焦
    details: Option-click 跳到最高优先级 agent：blocked → done → working → unknown → idle。
    link: /zh/guide/status
  - icon: 🪟
    title: 只聚焦，不创建
    details: 调用 agent.focus，再 tab.focus 让已经 attach 的 TUI 跟过去，然后举起宿主终端。从不新开窗口、pane 或 agent。
    link: /zh/guide/architecture#focus-raiser
  - icon: 🧩
    title: 每个 live session
    details: 同时发现 default 与 named session（如 work），按 (sessionName, pane_id) 聚合身份。
    link: /zh/guide/architecture#discovery
  - icon: 🎨
    title: Claude Code 调色板
    details: 默认颜色跟 Claude 终端 tab 对齐；working 用 CLI spinner 陶土色。齿轮里可覆盖。
    link: /zh/guide/configuration
---

::: info 这是什么
**herdr-bar** 是 [Herdr](https://herdr.dev/) 的 macOS 菜单栏伴侣。它直接连 Herdr 的 Unix socket，把多个 live session 里的 coding agent 收成一眼能读的计数，并让你跳回已经存在的 pane。

需要 Herdr 0.8+ 和 macOS 13+。应用是 `LSUIElement`，不出现在 Dock。
:::

## 常见问题

**herdr-bar 是什么？**
[Herdr](https://herdr.dev/) 的 macOS 菜单栏 extra。它不启动 Herdr，只发现 `herdr.sock`，显示 Done / Working 计数，Option-click 聚焦最高优先级 agent。

**怎么安装？**
从 [GitHub Releases](https://github.com/openalon-org/herdr-bar/releases) 下载带 tag 的 `HerdrBar-*-macos.zip`，或从源码跑 `./scripts/install.sh`。zip 是 ad-hoc 签名，第一次可能要右键 → 打开。详见 [安装](/zh/guide/installation)。

**会新建 pane 吗？**
不会。聚焦是 `agent.focus`，再 `tab.focus` / `pane.focus` 让已经 attach 的 TUI 跟过去，然后举起宿主终端。见 [使用](/zh/guide/usage) 和 [架构](/zh/guide/architecture)。
