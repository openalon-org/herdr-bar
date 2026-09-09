---
outline: false
---

# 使用

herdr-bar 有两层 UI：**菜单栏一览**（计数）和 **仪表盘**（跳转列表）。菜单栏不是完整清单。

## 菜单栏 {#menubar}

<div class="diagram">
  <p class="diagram-title">菜单栏一览（Done / Working 常驻）</p>
  <div class="chip-row">
    <span class="menubar-chip"><span class="dot" style="background:#00D75F"></span>0</span>
    <span class="menubar-chip"><span class="dot" style="background:#CF7650"></span>✻ 2</span>
    <span style="font-size:12px;color:var(--vp-c-text-3)">idle 不画 · blocked / unknown 有人时才插入 · 离线 = 22pt 点</span>
  </div>
</div>

| 交互 | 行为 |
|---|---|
| 左键 | 打开仪表盘 |
| Option-click | 聚焦最高优先级 agent |
| 右键 | 立刻 `agent.list` 刷新 |
| 全局热键 | 切换仪表盘（齿轮里绑定） |

在线时 Done / Working 常驻（含 0）。宽度贴着芯片，整组居中。Blocked / Unknown 或更宽的数字才会把菜单栏 extra 拉长。working 芯片用 Claude Code Darwin spinner（`·✢✳✶✻✽` 来回跳，120ms）。blocked / done / unknown 在计数 &gt; 0 时带呼吸光环，不是硬闪。按住时的高亮胶囊是系统画的；未按下时 extra 不再另画一层。

::: tip 为什么 idle 不上菜单栏
菜单栏只做一览。停着的 agent 仍然存在，用仪表盘头部的眼睛打开即可。
:::

## 仪表盘 {#dashboard}

Popover 固定 **372 × 480**。藏 idle 不会把窗口缩小后再长不回来（`NSPopover` 会记住上次高度）。

层级只有三层，没有第三排 chip：

1. **Session** — 顶行 scope chip：`All` / `default` / `work`（仅当 ≥2 个 session 在线）。点 chip 本体是筛选。具体 session（不是 All）名字后面有箭头，聚焦该 herdr session 列表的第一行（含 idle）。
2. **Folder** — 列表分区标题（`foreground_cwd` / `cwd` 的最后一段）
3. **Status** — 行颜色与优先级

头部：

- **图标** — 安静的 hierarchical `cpu` SF Symbol。Finder / 登录项 / About 是同一颗灰 `cpu`，浅色底。
- **眼睛** — 通知模式。默认开：混合组里藏 idle 行，纯 idle 组整组丢掉。
- **齿轮** — General（开机启动）、状态颜色、键盘（系统级打开快捷键 + 窗内快捷键说明）、About（app icon + 版本号 + 对照 GitHub Releases 检查更新）。

行内容：

- 标题来自 `name` / `display_agent` / `terminal_title` / `agent` / `pane_id`
- 副标题：`session · folder · branch · model`
- working 行：Darwin spinner、短模型名
- 状态在行右侧。不画耗时、不画 token —— 那些在 CLI 页脚，不在 herdr-bar

点一行 = `agent.focus` 那个 pane，然后举起宿主终端。

## 键盘 {#keyboard}

<div class="diagram">
  <p class="diagram-title">窗内 vs 系统级</p>
  <div class="kbd-row">
    <span class="kbd-pill"><kbd>↑</kbd><kbd>↓</kbd> 当前过滤下的任务</span>
    <span class="kbd-pill"><kbd>←</kbd><kbd>→</kbd> session chip；单 session 时切 folder</span>
    <span class="kbd-pill"><kbd>↩</kbd> 聚焦高亮行（无高亮则优先级 agent）</span>
    <span class="kbd-pill"><kbd>Esc</kbd> 先关设置，再关仪表盘</span>
  </div>
</div>

打开仪表盘的是 **系统级** Carbon 热键，不弹辅助功能权限。箭头和 Return 只在仪表盘打开时有效。

## 聚焦 {#focus}

聚焦永远是：

1. 在拥有该 pane 的 session 上调用 `agent.focus`
2. 举起已经在跑该 session TUI 的 GUI 终端（cmux / Otty / Ghostty / …）

它 **从不**：

- 创建 terminal / window / pane / tab / agent
- 激活 `herdr server`（监听 socket 的那个进程）
- 再发一层 OS 通知（Herdr 已经有 `[ui.toast]`）

目标是 `agent.name`，没有名字就用 `pane_id`。
