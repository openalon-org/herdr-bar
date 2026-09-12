---
outline: false
description: herdr-bar 如何把已接受的意图变成打了 tag 的 zip，以及人坐在哪些闸门上。
---

# 交付闭环

仓库里的非琐碎工作走一条会提交的闭环。聊天记录不是真相来源。剧本在 [`sdlc/README.md`](https://github.com/openalon-org/herdr-bar/blob/main/sdlc/README.md)（中文，人读的那份）。产品行为仍写在 [`AGENTS.md`](https://github.com/openalon-org/herdr-bar/blob/main/AGENTS.md)。

```text
intent (accepted) -> spec (approved) -> plan (engineer accepts)
  -> code + tests -> PR + REVIEW.md -> tag / zip (human)
  -> band breach / incident -> new intent
```

错别字、纯注释、CI yaml 小修可以跳过产物。PR 上写 `chore / no plan`。

## 闸门

人把 intent、spec、plan 的 `status` 翻成 `accepted`。那就是闸门。草稿不是改 `Sources/` 的许可。人仍然合并 PR、推 `v*`。没有 `RELEASE_APPROVAL` 时，agent 会话过不了 tag 闸门。

## 产物路径

| 阶段 | 写入 |
|---|---|
| Plan | `sdlc/intent/NNNN-slug.md` |
| Design | `sdlc/spec/NNNN-slug.md` |
| Build | `sdlc/plan/NNNN-slug.md`，然后是 diff |
| Test | `sdlc/evals/` |
| Ship | PR；GitHub Release zip |
| Maintain | `sdlc/incidents/` |

编号文件共用 slug。从 `sdlc/templates/` 复制。回滚是安装上一份 zip（`sdlc/runbooks/rollback-release.md`）。

## Skill 与 hook

`.agents/skills/` 下的 skill 是建议（`ai-native-sdlc`、`capture-intent`、`requirements-design`、`plan-mode`、`depersonalize`）。`.claude/settings.json` 里的 hook 是确定性的：没有批准不能推 `v*`，Edit/Write 不能写真实 home，不能悄悄改 `Herdr.js`。

## 评测与带宽

`scripts/run-evals.sh` 总会检查每条 case 仍能在引用文件里找到 `must_hold` 原文。现场 `claude -p` 是下一出；workflow 即使有 key 也打印 `skip live evals`。

`scripts/detect-bands.py` 读 `bands.yaml`。检测没有模型。周任务对合成 fixture 跑检测器并打印档位，不开 GitHub issue。1σ 记录、2σ 诊断、3σ 提议仍是以后那一出的契约。分诊是人做的。

## 不在本仓库

托管安全扫描和 Slack 值班是企业产品。漏洞仍走 [`SECURITY.md`](https://github.com/openalon-org/herdr-bar/blob/main/SECURITY.md)。以 GitHub issue 进来的事故走同一条 intent 路径。
