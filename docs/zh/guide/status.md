---
outline: false
description: 五种 agent 状态、优先级、菜单栏一览规则，以及 folder 分组。
---

# 状态模型

各 agent 运行时各自解释自己在干什么。herdr-bar **不**二次解读——它只规范化 Herdr 已经给出的 `agent_status`。

## 五种状态 {#states}

未知字符串（含缺字段）落到 `unknown`。顺序写死在 `AgentStatus.order`：

<div class="diagram">
  <p class="diagram-title">优先级（越小越先被 Option-click 选中）</p>
  <div class="priority-list">
    <div class="priority-row"><span class="rank">0</span><span class="status-swatch blocked"></span><strong>blocked</strong><span>在等你</span></div>
    <div class="priority-row"><span class="rank">1</span><span class="status-swatch done"></span><strong>done</strong><span>一轮结束</span></div>
    <div class="priority-row"><span class="rank">2</span><span class="status-swatch working"></span><strong>working</strong><span>正在跑</span></div>
    <div class="priority-row"><span class="rank">3</span><span class="status-swatch unknown"></span><strong>unknown</strong><span>读不出</span></div>
    <div class="priority-row"><span class="rank">4</span><span class="status-swatch idle"></span><strong>idle</strong><span>停着</span></div>
  </div>
</div>

`needsAttention`：blocked、done、unknown。这些在菜单栏带呼吸光环。working 和 idle 不算 attention。

图标两套：Nerd Font PUA（遗留 / 跨平台）和 SF Symbols（macOS 仪表盘）。Tooltip 用 BMP：`! ✓ … ? –`。

## 优先级 {#priority}

**Option-click / 无高亮时按 Return** 走 `attentionAgent`：

1. 按上面的状态顺序
2. 同优先级看最新的 `state_change_seq`

这是跨 session 的「现在该看谁」。列表排序是另一套，见下面。

## 菜单栏一览 {#glance}

菜单栏是仪表，不是完整清单。

- Idle **从不**上栏。眼睛只影响仪表盘。
- 在线时 **Done 和 Working 常驻**，计数为 0 也留槽、全色。没有 Done 不画光环，没有 Working 不转 spinner。
- Blocked / Unknown 只在计数 &gt; 0 时插入（等人处理）。
- 离线 → 22pt 点。
- 宽度贴着这组芯片（+ 4pt inset）。数字进位，或 Blocked / Unknown 插入时，才会变宽。
- working 标记槽宽固定 12pt，避免 `·` / `✽` 把数字挤歪。
- 不要给 extra 画休息态胶囊：按住时的玻璃是 `NSStatusBarButton` 的。自定义 view 必须透明（`isOpaque = false`，不 `super.draw`），否则会盖住 Tahoe 邻接缝。

## 分组与排序 {#grouping}

Session 是 **过滤器**，不是排序键。`All` 和单个 session 用同一套 folder 分组。

**组（folder）**

- 桶：`folderName(foregroundCwd ?? cwd)`
- 组里有非 idle：按该组最高优先级状态，然后 folder 名
- 纯 idle 组：按该空间最新对话时间（`~/.claude/projects/.../<uuid>.jsonl` 的 mtime，经 `agent_session.value`）。缺时间的排最后

**组内行**

1. 状态优先级
2. `lastSessionAt` 新的在前（刚变成 Idle 的 Done 压过更老的 idle pane）
3. pane 号（`w2:p7` / `p7`）—— 只当排序键，不画在行上
4. 标签，不区分大小写

::: warning 不要用 `state_change_seq` 做 All 视图的跨 session 排序
序号是每个 Herdr 进程自己的。拿它排 All 会把无关 session 搅在一起。它只用于「同优先级时谁更需要注意力」。
:::

Working / Done 行的模型名也来自同一份 jsonl，不是 Claude statusline 的 stdin：

- `modelName` — 最近一条 assistant `message.model`，缩成 `Opus 4.6` / `Grok 4.6`
- 不画耗时、不画 token。jsonl 不是 CLI 页脚（`16m 51s · ↓ 8.8k`）；用 transcript 时间戳 / `usage` 猜出来的是错的数字
- 运动 — Darwin spinner，`floor(ms/120) % 12`。idle / done / blocked / unknown 停在同一个 14pt 槽的 `✻` 上，没有 4px 状态条
