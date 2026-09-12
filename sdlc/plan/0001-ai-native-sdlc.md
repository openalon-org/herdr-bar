---
id: "0001"
title: 采纳 AI-native SDLC
status: accepted
intent: sdlc/intent/0001-ai-native-sdlc.md
spec: sdlc/spec/0001-ai-native-sdlc.md
---

# 计划：采纳 AI-native SDLC

没看过聊天记录的工程师应能按本文件落地。实现若偏离，在同一提交里改这份计划。

## 改动的文件

新建：

- `CLAUDE.md`、`REVIEW.md`、`bands.yaml`
- `sdlc/README.md`、`sdlc/workflow-graph.yaml`
- `sdlc/templates/{intent,spec,plan,incident}.md`
- `sdlc/intent/0001-ai-native-sdlc.md`、`sdlc/spec/0001-ai-native-sdlc.md`、`sdlc/plan/0001-ai-native-sdlc.md`
- `sdlc/evals/README.md`、`sdlc/evals/cases/*.json`（10）
- `sdlc/incidents/README.md`、`sdlc/runbooks/rollback-release.md`
- `scripts/hooks/{production-gate,depersonalize,protect-oracle}.{sh,py}`
- `scripts/run-evals.sh`、`scripts/run-evals.py`、`scripts/detect-bands.py`
- `.claude/settings.json`、`.claude/agents/{verifier,researcher}.md`
- `.agents/skills/{ai-native-sdlc,capture-intent,requirements-design,plan-mode,depersonalize}/SKILL.md`
- `.github/workflows/{agent-evals,maintain-bands}.yml`
- `tests/sdlc.test.mjs`
- `docs/guide/sdlc.md`、`docs/zh/guide/sdlc.md`

已有：

- `AGENTS.md` — 交付段、仓库地图、验证命令
- `CONTRIBUTING.md` — 非琐碎工作从 intent 开始
- `docs/guide/development.md`、`docs/zh/guide/development.md` — 仓库地图 + 测试命令
- `docs/.vitepress/config.ts` — `sdlc` 侧栏键
- `.github/workflows/ci.yml` — 加上 `tests/sdlc.test.mjs`
- `.github/pull_request_template.md`、issue 模板 — 产物链
- `.gitignore` — 忽略 `.claude/worktrees/`

不要动 `Sources/`、`Herdr.js`、`CHANGELOG.md`、`scripts/reload.sh`。

人读的 `sdlc/` 正文用中文。代理读的 `CLAUDE.md` / skills / `REVIEW.md` / 评测 prompt 用英文。站点仍双语。

## 工作顺序

1. 模板 + `0001` 意图 / 规格 / 计划（本文件）。
2. 根目录剧本文件和 `sdlc/README.md` + 图。
3. Hook 脚本、`.claude/settings.json`、subagent。
4. Skill。
5. 评测 case、`run-evals.sh`、`detect-bands.py`、workflow。
6. `tests/sdlc.test.mjs` 直到绿。
7. 文档英/中、侧栏、`AGENTS.md`、`CONTRIBUTING.md`、issue/PR 模板。

共享文件保持串行。测试锁住契约之后，文档和 skill 可以并行。

实现偏离：hook 拆成 `.sh` 包装 `.py`（heredoc 会偷走 stdin）；空 payload 放行以免卡死会话（缺字段不再 fail closed）；去人格化只扫写入正文，不扫磁盘上的 `file_path`；本机工程路径和保留 session 名在 hook 源码里拼出来，不把禁止拼写写进仓库。人读产物在落地时改成中文。现场 `claude -p` 和按档开 issue 没有接上，文档改口成下一出。

## 风险

- 最险：hook 的 JSON stdin 形状 vs Claude Code 实际送来的 — 脚本对缺字段必须 fail closed，同时能用 stdin 上的 fixture 单测。
- 放弃：整棵抄 `bashebr/ai-native-sdlc`（记账示例、组织图、Codex 插件）。本仓库已有章程和 skill 布局。
- 放弃：把不变量搬进 `CLAUDE.md`。剧本要的是一页 day-one；`AGENTS.md` 才是产品。
- 放弃：默认 CI 强制要 `ANTHROPIC_API_KEY`。

## 验收

```bash
node --test tests/sdlc.test.mjs tests/changelog.test.mjs tests/herdr.test.mjs
swift test
npm run docs:build && node --test tests/from-markdown.test.mjs tests/seo.test.mjs
git grep -nE '/Users/|/home/|eden|client\.new' -- . ':!package-lock.json'
```

不要跑 `scripts/reload.sh` — extra / 核心没改。健康的 Node 输出：全部通过，exit 0。文档构建写出 `docs/.vitepress/dist` 里的 `guide/sdlc.html` 和 `zh/guide/sdlc.html`。
