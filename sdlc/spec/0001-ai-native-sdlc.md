---
id: "0001"
title: 采纳 AI-native SDLC
status: accepted
intent: sdlc/intent/0001-ai-native-sdlc.md
---

# 规格：采纳 AI-native SDLC

先读已接受的意图。套用 `AGENTS.md`。发现矛盾就标出来，不要糊过去。

## 需求

1. 根目录有剧本文件：`CLAUDE.md`（一页命令和反复踩过的坑）、`REVIEW.md`（Bugs / Security / Compliance）、`bands.yaml`（CI 失败率档位）。
2. `sdlc/` 放模板、编号实例、评测、事故和 workflow 图。编号文件共用 slug。frontmatter `status: accepted` 是人闸门。人读正文用中文。
3. Skill `ai-native-sdlc`、`capture-intent`、`requirements-design`、`plan-mode`、`depersonalize` 在 `.agents/skills/`（`.claude/skills` 已经软链过去）。现有的 `test-reload`、`release`、`vitepress-gtm` 留下。
4. Subagent `verifier` 和 `researcher` 在 `.claude/agents/`。Verifier 只汇报，不修。
5. 提交的 `.claude/settings.json` 接三条 hook：生产 tag/release 闸门、Edit/Write 去人格化、`Herdr.js` 和 `tests/herdr.test.mjs` 的 oracle 锁。
6. 十条评测 case 编码真实不变量。CI 总检查 schema 和 `must_hold` 字符串。现场 `claude -p` 是下一出；这次的 workflow 打印 `skip live evals`。
7. 确定性带宽检测器（没有模型）给合成失败率分档。每周 workflow 对 fixture 跑检测器并打印 JSON。按档评论 / 开事故是下一出。
8. 文档：`docs/guide/sdlc.md` 和 `docs/zh/guide/sdlc.md`，侧栏在开发页之后，仓库地图更新。`AGENTS.md` 和 `CONTRIBUTING.md` 指向闭环。
9. Issue 和 PR 模板提到产物链。不改 extra 行为。不写 changelog 小节。

## 设计

- 真相来源是 git 仓库。Issue 仍是入口。
- `CLAUDE.md` 指向 `AGENTS.md` 和 `sdlc/`；不复制不变量。
- Hook 是 skill 建议之上的确定性层。Skill 让违规变少；hook 让三条具名策略在会话里接近不可能。
- 本产品的生产是 `git push` `v*` / `gh release`。extra 从不自己部署。
- 回滚是安装上一份 GitHub Release zip（`sdlc/runbooks/rollback-release.md`）。
- 评测挨着它保护的章程。引用某句原文的 case 必须还能找到那句。

## 风险 / 顾虑

- 流程文件漏出真实 home、登录名、本地工程路径、或 `work` 以外的真实 session 名。负责人：每个作者。缓解：去人格化 hook + `tests/sdlc.test.mjs` grep + 现有的 `git grep` 扫描。
- Agent 一旦有了 `CLAUDE.md` 就把 `AGENTS.md` 当可选。负责人：维护者。缓解：`CLAUDE.md` 第一行指向不变量；评测 `must_hold` 对着 `AGENTS.md`。
- 没设 API key 时现场评测把默认 CI 打红。负责人：平台。缓解：结构套件是默认闸门；现场跑是尽力而为。
- production-gate hook 误伤普通分支的 `git push`。负责人：hook 脚本。缓解：只匹配 tag 推送（`v*`）、`gh release`、以及同时出现 `deploy` 和 `production` 的命令——不是普通分支推送。
- 假装本仓库有 Claude Security / Tag。负责人：文档。缓解：一节「不在本仓库」；路径仍是 `SECURITY.md` 和 issues。
- 去人格化 hook 把克隆的绝对路径（磁盘上的 `/Users/<you>/…`）当成写入正文。负责人：hook。缓解：只扫 `content` / `old_string` / `new_string`，不扫 `file_path`。
