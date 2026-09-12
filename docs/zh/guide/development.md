---
outline: false
description: 本地构建、测试并 reload herdr-bar。Swift 包 + VitePress 文档站。
---

# 开发

Swift 6 package，macOS 13+。三个 product：库 `HerdrCore`，可执行文件 `MacBar`（Carbon、ServiceManagement、WidgetKit），可执行文件 `HerdrWidget`（只做编译检查）。画廊小组件是 `WidgetExtension/` 里真正的 app-extension（`xcodebuild`），打成 `HerdrWidget.appex`。

## 仓库地图 {#map}

```text
Sources/HerdrCore/     协议、发现、聚合、富化、举起宿主、小组件快照
Sources/MacBar/        NSStatusItem、dashboard popover、设置、热键、快照写入
Sources/HerdrWidget/   WidgetKit Medium / Large（appex 源码）
WidgetExtension/       XcodeGen app-extension 工程；package-app.sh 跑 xcodebuild
Herdr.js               行为对照（状态顺序、计数、socket 路径）
tests/herdr.test.mjs   Node 侧行为对照测试
tests/HerdrCoreTests/  Swift 模型与协议测试
tools/demo-server.py   newline JSON fixture
scripts/dev-run.sh     本地运行（可选 --demo）
scripts/package-app.sh 打 HerdrBar.app（本机架构；CI 用 HERDR_BAR_UNIVERSAL=1）。版本优先 HERDR_BAR_VERSION，否则精确 git tag，再否则 `<最近 tag>-dev`
scripts/render-app-icon.swift SF Symbol `cpu` → AppIcon.icns（package-app.sh 调用）
scripts/install.sh     包装 package-app.sh 到 ~/Applications（不杀旧进程）
scripts/reload.sh      swift test → 安装 → 杀掉 MacBar 和残留的 HerdrWidget → 打开新 extra
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
| `WidgetSnapshot` | extra → `widget-snapshot.json` → WidgetKit；`herdr-bar://focus` |
| `WorkingSpinner` | Darwin `·✢✳✶✻✽` ping-pong |

## 测试 {#tests}

```bash
swift test
node --test tests/herdr.test.mjs tests/changelog.test.mjs
```

CI（`.github/workflows/ci.yml`）在 `macos-latest` 上跑这两条。Ubuntu 的 `docs` job 会 build VitePress，再跑 `tests/seo.test.mjs`（canonical、hreflang、sitemap、robots）。另有 Pages workflow 部署同一份产物。打 `v*` tag 走 `.github/workflows/release.yml`：编 universal `.app`，zip 挂到 GitHub Release，正文是 `scripts/changelog-notes.sh` 抽出的那一节。tag 必须对应 `CHANGELOG.md` 里的 `## [X.Y.Z]`。二进制是 ad-hoc 签名（不是 Developer ID / 公证）。`workflow_dispatch` 只上传 artifact。

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

`reload.sh` 会杀掉所有 `MacBar`（包括 `dev-run.sh` 拉起的）以及残留的 `HerdrWidget` 进程，再 `open ~/Applications/HerdrBar.app`。Agent 走 `.agents/skills/test-reload`（`.claude/skills` 是指向 `.agents/skills` 的软链）。

## 文档站 {#docs}

本目录是 VitePress 源。

```bash
npm install
npm run docs:dev       # 终端会打印本地地址
npm run docs:build
npm run docs:preview
```

推到 `main` 时，GitHub Actions 把 `docs/.vitepress/dist` 发到 GitHub Pages。站点默认英文，中文在 `/zh/`。项目站的 `base` 是 `/herdr-bar/`；本地 dev 用 `/`。canonical、Open Graph、JSON-LD、`sitemap.xml`、`robots.txt` 共用 `https://openalon.com/herdr-bar/`（`docs/.vitepress/seo.ts`）。每页 description 和 FAQ JSON-LD 在构建时从 markdown 抽出（`docs/.vitepress/from-markdown.mjs`）——新的 `docs/guide/*.md` 加上 `docs/zh/` 对照页会自动带上，不用再维护一张表。首段不适合做 snippet 时，用 frontmatter `description:` 覆盖（架构、协议、不变量、开发、更新日志已经这样写）。缺 `docs/zh/` 对照页时不写那条 hreflang，避免指向 404。社交图是 `docs/public/og.png`（1200×630）。仓库在 [openalon-org/herdr-bar](https://github.com/openalon-org/herdr-bar)。`/changelog` include 根目录 `CHANGELOG.md`，不要在 `docs/` 里再抄一份。第一次上线 sitemap 后，到 [Google Search Console](https://search.google.com/search-console) 提交 `https://openalon.com/herdr-bar/sitemap.xml`。
