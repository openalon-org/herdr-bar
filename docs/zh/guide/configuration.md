---
outline: false
---

# 配置

偏好写在 `~/.config/herdr/herdr-bar.json`，和 Herdr 自己的配置放在一起。齿轮改的值和手改文件是同一份；进程会监视该目录并热加载颜色。

## 配置文件 {#file}

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

规则：

- 文件可以缺字段。缺省 = 产品默认。
- `hideIdle` 默认 `true`。为 true 时 **不写进磁盘**，所以「只改过颜色」的文件仍然只有 `colors`。
- `hotkey` 缺省 = 未绑定。`keyCode` 是 Carbon 硬件虚拟键（`kVK_*`），修饰键是 Cocoa 风格的布尔。
- 根对象变空时文件会被删掉。

## 状态颜色 {#colors}

默认对齐 [Claude Code](https://code.claude.com/docs) 终端 tab-status。working 例外：用 CLI spinner 陶土色 `#CF7650`，在浅色 popover 上仍然可读。

| 状态 | 默认 | 含义 |
|---|---|---|
| <span class="status-swatch blocked"></span>blocked | `#5F87FF` | Claude `waiting` — 在等你 |
| <span class="status-swatch done"></span>done | `#00D75F` | 一轮结束 |
| <span class="status-swatch working"></span>working | `#CF7650` | CLI spinner 陶土色（浅色终端上的 `Bunning…`） |
| <span class="status-swatch unknown"></span>unknown | `#C7A35A` | 读不出的状态 |
| <span class="status-swatch idle"></span>idle | `#888888` | Claude idle `statusColor` |

在齿轮里点色块覆盖某一项。恢复默认会丢掉该项覆盖。有覆盖时标题栏出现 **Reset**。设置页会标 **Custom**，不再印十六进制说明。

色块是 SwiftUI `ColorPicker`（macOS 胶囊样式）。打开取色板时 popover 切到 `.applicationDefined`，避免 `NSColorPanel` 把瞬时 popover 关掉。

## 通知模式 {#hide-idle}

`hideIdle`（默认 true）控制仪表盘，**不影响**菜单栏（菜单栏永远不画 idle）：

- 组里还有非 idle 行 → 藏起 idle 行，header 可显示藏了几条
- 组里全是 idle → 整组不出现

点头部眼睛切换。想默认看见停着的 agent，把 `hideIdle` 写成 `false`。

## 全局快捷键 {#hotkey}

齿轮 → **Keyboard → Open dashboard**。点一下快捷键井，按住 ⌘ / ⌥ / ⌃ 再加一个键。Carbon `RegisterEventHotKey`，不走辅助功能权限。

冲突时页脚变成 *That shortcut is already taken*。**Clear** 删掉绑定。

JSON 示例（⇧⌘Space，`kVK_Space` = 49）：

```json
{
  "hotkey": {
    "keyCode": 49,
    "command": true,
    "shift": true
  }
}
```

同一组里还列出窗内快捷键：↑↓ 走任务，←→ 走 session / folder，↩ 聚焦。

## 开机启动 {#login}

齿轮 → **General → Open at login**。走的是 `SMAppService.mainApp`，和 **系统设置 → 通用 → 登录项** 是同一份名单，不是 `herdr-bar.json` 里的字段。第一次打开时 macOS 可能要你批准。

`swift run` / `dev-run.sh` 的裸二进制不能注册。先打成 `HerdrBar.app`（`./scripts/install.sh`）。开关拨了还是关着，页脚会说明原因；**Open Login Items** 会跳到系统那一页。

## 更新 {#updates}

齿轮 → **About**。extra 读 `CFBundleShortVersionString`，对照 GitHub `/repos/openalon-org/herdr-bar/releases/latest`。没有 Sparkle 安装路径——有更新时打开 Release 页。本地 `swift run` / 未打包二进制显示 `dev`。
