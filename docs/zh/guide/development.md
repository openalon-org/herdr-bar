---
outline: false
---

# 开发

Swift 6 package，macOS 13+。两个 product：库 `HerdrCore`，可执行文件 `MacBar`（链接 Carbon 给全局热键，ServiceManagement 给开机启动）。

## 仓库地图 {#map}

```text
Sources/HerdrCore/     协议、发现、聚合、富化、举起宿主
Sources/MacBar/        NSStatusItem、dashboard popover、设置、热键
Herdr.js               行为对照（状态顺序、计数、socket 路径）
tests/herdr.test.mjs   Node 侧行为对照测试
tests/HerdrCoreTests/  Swift 模型与协议测试
tools/demo-server.py   newline JSON fixture
scripts/dev-run.sh     本地运行（可选 --demo）
scripts/package-app.sh 打 HerdrBar.app（本机架构；CI 用 HERDR_BAR_UNIVERSAL=1）
scripts/render-app-icon.swift SF Symbol `cpu` → AppIcon.icns（package-app.sh 调用）
scripts/install.sh     包装 package-app.sh 到 ~/Applications（不杀旧进程）
scripts/reload.sh      swift test → 安装 → 杀掉 MacBar → 打开新 extra
scripts/changelog-notes.sh  抽出 CHANGELOG.md 某一节作为 GitHub Release 正文
CHANGELOG.md           Keep a Changelog（文档站 /changelog 直接 include 这份）
.agents/skills/        项目 skill 正文（test-reload、release）
.claude/skills         → ../.agents/skills
docs/                  本 VitePress 站点（英文为根，中文在 /zh/）
```

关键类型：

| 类型 | 职责 |
|---|---|
| `HerdrClient` | JSON-RPC 读写 |
| `SessionWatcher` | 每 socket：list + subscribe + 重连 |
| `SessionManager` | 发现、监视目录、聚焦编排 |
| `AgentAggregator` | 合并 online session |
| `HerdrLogic` | 纯函数：过滤、分组、计数、标签 |
| `FocusRaiser` | 找到并激活宿主 GUI |
| `StatusPalette` / `AppPreferences` | `herdr-bar.json` |
| `LoginItem` | 开机启动的 UI 映射（`SMAppService` 在 MacBar） |
| `BrandMark` | dashboard header 用安静的 `chrome` SF Symbol；About 用 `badge` icns |
| `WorkingSpinner` | Darwin `·✢✳✶✻✽` ping-pong |

## 测试 {#tests}

```bash
swift test
node --test tests/herdr.test.mjs tests/changelog.test.mjs
```

CI（`.github/workflows/ci.yml`）在 `macos-latest` 上跑这两条。文档站另有 Pages workflow，在 Ubuntu 上 build VitePress。打 `v*` tag 走 `.github/workflows/release.yml`：编 universal `.app`，zip 挂到 GitHub Release，正文是 `scripts/changelog-notes.sh` 抽出的那一节。tag 必须对应 `CHANGELOG.md` 里的 `## [X.Y.Z]`。二进制是 ad-hoc 签名（不是 Developer ID / 公证）。`workflow_dispatch` 只上传 artifact。

行为变化应带上最窄有用的测试。改了安装、设置、交互或前置条件时，同步 README 和 `docs/guide/`。用户能看见的历史写在 `CHANGELOG.md`，发版时再改（skill `release`）。

## 本地运行 {#run}

```bash
./scripts/dev-run.sh              # 默认 + named session
./scripts/dev-run.sh --demo       # fixture
HERDR_SOCKET=/tmp/x.sock ./scripts/dev-run.sh
swift run --package-path . MacBar
```

`--demo` 在后台拉起 `tools/demo-server.py`，把 `HERDR_SOCKET` 指到 `/tmp/herdr-demo.sock`，退出时清掉。

源码和 `swift test` **不会**换成菜单栏里那份。改 extra / HerdrCore 之后要让用户看见：

```bash
./scripts/reload.sh              # 默认先 swift test
./scripts/reload.sh --skip-tests # 本轮测试已经过
./scripts/reload.sh --all-tests  # 再加上 node 行为对照
```

`reload.sh` 会杀掉所有 `MacBar`（包括 `dev-run.sh` 拉起的），再 `open ~/Applications/HerdrBar.app`。Agent 走 `.agents/skills/test-reload`（`.claude/skills` 是指向 `.agents/skills` 的软链）。

## 文档站 {#docs}

本目录是 VitePress 源。

```bash
npm install
npm run docs:dev       # 终端会打印本地地址
npm run docs:build
npm run docs:preview
```

推到 `main` 时，GitHub Actions 把 `docs/.vitepress/dist` 发到 GitHub Pages。站点默认英文，中文在 `/zh/`。项目站的 `base` 是 `/herdr-bar/`；本地 dev 用 `/`。仓库在 [openalon-org/herdr-bar](https://github.com/openalon-org/herdr-bar)。`/changelog` include 根目录 `CHANGELOG.md`，不要在 `docs/` 里再抄一份。
