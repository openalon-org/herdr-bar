---
id: "0001"
title: 采纳 AI-native SDLC
status: accepted
slug: 0001-ai-native-sdlc
issue: ""
originator: openalon
---

# 意图：采纳 AI-native SDLC

## 问题

herdr-bar 已经有产品章程（`AGENTS.md`）、和工作树不是同一份的活 extra、以及打 tag 才发的 zip。Agent 会话仍从聊天开始。意图、规格、计划死在 transcript 里。评审是谁在键盘前谁说了算。没有确定性的东西拦住会话去打 `v*` 或贴真实 home 路径。生产信号也不会作为新意图再进来。

代码已经不是瓶颈。缺的是生命周期的其余部分。

## 预期结果

每一项非琐碎改动都提交下一阶段能读的产物：

```text
intent (accepted) → spec (approved) → plan (engineer accepts)
  → code + tests → PR + REVIEW.md → tag / zip (human)
  → band breach / incident → new intent
```

人批准意图、规格、未解决的 spec/plan 冲突、PR 合并、以及生产 tag。Agent 可以走到 tag 闸门前，过不去。extra 的用户可见行为不变。

## 影响的用户与系统

- 在这棵树里工作的维护者和 agent。
- GitHub Issues（只作入口；仓库才是真相来源）。
- CI（`swift test`、Node oracle、文档构建）加上新的结构评测和每周带宽检查。
- Claude Code 的项目 skill、hook 和 subagent。

不影响：菜单栏 extra、dashboard、小组件、Herdr socket、ad-hoc zip。

## 约束

- 不改 extra / HerdrCore 行为。不要 Sparkle，不要自安装，不要 Developer ID。
- `AGENTS.md` 仍是产品章程。不要把不变量搬进 `CLAUDE.md`。
- 发布树保持去人格化（`/Users/me`、`/home/user`、`~/…`、session `work`）。
- 站点仍双语（英文为根，简体中文在 `docs/zh/`）。本闭环里人读的产物（`sdlc/` 模板、编号文件、runbook、说明）用中文。代理读的 `CLAUDE.md`、skills、`REVIEW.md`、评测 prompt 用英文。
- Git 是真相来源。GitHub Issues 仍是入口；已接受的 `sdlc/intent/*.md` 才是 Design 读的记录。
- Claude Security 和 Claude Tag 不在本仓库。Maintain 用 Actions + issues。
- 不写用户可见的 `CHANGELOG.md` 小节（流程和文档不进 release skill）。

## 未决问题

- 现场 `claude -p` 评测需要 `ANTHROPIC_API_KEY`。结构检查必须在没有它时也能过。
- 公开 MIT extra 不做 managed / MDM 设置。
