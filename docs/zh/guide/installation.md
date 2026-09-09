---
outline: false
---

# 安装

把 herdr-bar 装成菜单栏 extra，连上本机已经在跑的 Herdr。

## 前提条件 {#prerequisites}

- **macOS 13+**
- **Swift**（Xcode 或 Command Line Tools）
- **Herdr 0.8+**，并且至少有一个 session 在跑（`herdr` 或 `herdr session attach <name>`）
- 本机有 Herdr socket：
  - default：`~/.config/herdr/herdr.sock`
  - named：`~/.config/herdr/sessions/<name>/herdr.sock`

::: tip 先确认 Herdr 在线
herdr-bar 自己不启动 Herdr。菜单栏如果只剩一颗 22pt 灰点，多半是 socket 还不存在，而不是安装失败。
:::

## 安装 {#steps}

推一个 `v*` tag 后，`.github/workflows/release.yml` 会编一份 universal `HerdrBar.app`，打成 zip 挂到 GitHub Release。二进制只有 ad-hoc 签名——没有 Developer ID、没有公证、也没有 Sparkle 自动更新（那条发布线需要本仓库没有的 Apple 证书）。齿轮 → About 可以对照 GitHub Releases 并打开最新 tag，但不能替换正在运行的 extra。下载解压后：

```bash
xattr -cr HerdrBar.app
open HerdrBar.app
```

第一次可能要右键 → 打开。

或从源码构建并放到 `~/Applications/HerdrBar.app`：

```bash
git clone https://github.com/openalon-org/herdr-bar.git
cd herdr-bar
./scripts/install.sh
open ~/Applications/HerdrBar.app
```

`install.sh` 会调 `scripts/package-app.sh`（本机架构，不是 universal）：

1. `swift build -c release --product MacBar`
2. 写出 `~/Applications/HerdrBar.app`（`LSUIElement`，bundle id `dev.herdr.herdr-bar`）
3. 把二进制放进 `Contents/MacOS/MacBar` 并 ad-hoc `codesign`

应用不出现在 Dock。菜单栏右侧会出现一颗点（全 idle / 离线）或一组状态 chip。

`install.sh` 不杀正在跑的 `MacBar`。改完源码要换成菜单栏里那份：`./scripts/reload.sh`（先 `swift test`，再安装并重启 extra）。

## 首次启动 {#first-run}

1. 打开 Herdr TUI（default 或 named session）。
2. 打开 `HerdrBar.app`。
3. 左键菜单栏计数 → 打开仪表盘。
4. Option-click → 聚焦最高优先级 agent。
5. 右键 → 立刻刷新。

::: warning 登录项
macOS 不会自动开机启动。需要的话在 **系统设置 → 通用 → 登录项** 里把 `HerdrBar` 加上。
:::

## 演示模式 {#demo}

没有 Herdr 也能看 UI。fixture 会在 `/tmp/herdr-demo.sock` 上模拟 newline JSON-RPC，并循环几组状态：

```bash
./scripts/dev-run.sh --demo
```

`HERDR_SOCKET` 会固定单个 socket，发现层把它命名为 `demo`，不再扫描 `~/.config/herdr`。

```bash
HERDR_SOCKET=/path/to/herdr.sock ./scripts/dev-run.sh
```

开发期的 throwaway 运行（不安装 app bundle）：

```bash
./scripts/dev-run.sh
```
