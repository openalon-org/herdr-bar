---
outline: false
description: Five agent states, priority order, menu-bar glance rules, and folder grouping.
---

# Status model

Each harness decides what an agent is doing. herdr-bar does **not** reinterpret that — it only normalizes the `agent_status` Herdr already sent.

## Five states {#states}

Unknown strings (including a missing field) fall through to `unknown`. Order is fixed in `AgentStatus.order`:

<div class="diagram">
  <p class="diagram-title">Priority (lower rank wins Option-click)</p>
  <div class="priority-list">
    <div class="priority-row"><span class="rank">0</span><span class="status-swatch blocked"></span><strong>blocked</strong><span>waiting on you</span></div>
    <div class="priority-row"><span class="rank">1</span><span class="status-swatch done"></span><strong>done</strong><span>turn finished</span></div>
    <div class="priority-row"><span class="rank">2</span><span class="status-swatch working"></span><strong>working</strong><span>running</span></div>
    <div class="priority-row"><span class="rank">3</span><span class="status-swatch unknown"></span><strong>unknown</strong><span>unreadable</span></div>
    <div class="priority-row"><span class="rank">4</span><span class="status-swatch idle"></span><strong>idle</strong><span>parked</span></div>
  </div>
</div>

`needsAttention`: blocked, done, unknown. Those get the breathing halo on the extra. Working and idle do not.

Two icon sets: Nerd Font PUA (legacy / cross-platform) and SF Symbols (macOS dashboard). Tooltips stay in BMP: `! ✓ … ? –`.

## Priority {#priority}

**Option-click / Return with no highlight** uses `attentionAgent`:

1. Status order above
2. Newest `state_change_seq` on a tie

That answers “who needs me now” across sessions. List sort is a different rule — see below.

## Menu-bar glance {#glance}

The extra is a glance, not a full inventory.

- Idle **never** appears there. The eye only affects the dashboard.
- While online, **Done and Working stay put**, including a 0 at full color. No Done → no halo. No Working → no spinner.
- Blocked / Unknown insert only when the count is above 0 (someone is waiting).
- Offline → 22pt dot.
- Width hugs this cluster (`+ 4pt inset`). Digit rollover, or a Blocked / Unknown chip inserting, can grow it.
- Working-mark slot is a fixed 12pt so `·` / `✽` cannot shove the digits.
- Do not paint a rest-state capsule on the extra: the press glass belongs to `NSStatusBarButton`. The custom view stays transparent (`isOpaque = false`, no `super.draw`) so Tahoe neighbor seams show through.

## Grouping {#grouping}

Session is a **filter**, not a sort key. `All` and a single session share the same folder grouping.

**Groups (folders)**

- Bucket: `folderName(foregroundCwd ?? cwd)`
- A group with any non-idle row: sort by that group’s highest-priority status, then folder name
- Idle-only groups: newest conversation time in that space (`~/.claude/projects/.../<uuid>.jsonl` mtime via `agent_session.value`). Missing times last

**Rows inside a group**

1. Status priority
2. Newer `lastSessionAt` first (a Done that just became Idle stays above older idle panes)
3. Pane number (`w2:p7` / `p7`) — sort key only, not drawn on the row
4. Label, case-insensitive

::: warning Do not sort All with `state_change_seq`
The sequence is per Herdr process. Using it across sessions in All mixes unrelated work. It is only the tie-break for attention.
:::

Working / Done model names also come from that jsonl — not Claude statusline stdin:

- `modelName` — latest assistant `message.model`, shortened to `Opus 4.6` / `Grok 4.6`
- Do not draw elapsed time or tokens. jsonl is not the CLI footer (`16m 51s · ↓ 8.8k`); guessing from transcript timestamps / `usage` is the wrong number
- Motion — Darwin spinner, `floor(ms/120) % 12`. idle / done / blocked / unknown park on `✻` in the same 14pt slot — no 4px status bar
