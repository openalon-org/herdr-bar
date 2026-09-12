# 交付闭环

herdr-bar 按 [AI-native SDLC 剧本](https://claude.com/blog/the-ai-native-sdlc-playbook) 跑。每一阶段提交下一阶段能读的产物。人坐在闸门上。

```text
intent (accepted) → spec (approved) → plan (engineer accepts)
  → code + tests → PR + REVIEW.md → tag / zip (human)
  → band breach / incident → new intent
```

Git 是真相来源。GitHub Issues 是入口。产品行为仍写在 [`AGENTS.md`](../AGENTS.md)。

人读的产物（本目录的模板、编号文件、runbook、evals / incidents 说明）用中文。代理读的 `CLAUDE.md`、skills、`REVIEW.md`、评测 JSON 的 prompt 用英文。frontmatter 键保持英文（`status: accepted` 就是闸门）。

## 产物

| 阶段 | 写入 | 闸门 |
|---|---|---|
| Plan | `sdlc/intent/NNNN-slug.md` | 提出人 + 维护者把 `status` 翻成 `accepted` |
| Design | `sdlc/spec/NNNN-slug.md` | 维护者接受 |
| Build | `sdlc/plan/NNNN-slug.md`，然后是 diff | 工程师在改代码前接受 plan |
| Test | 测试输出、`sdlc/evals/` | CI + 会话反馈环 |
| Deploy | PR、GitHub Release zip | 人打 `v*`；hook 拦住 agent |
| Maintain | `sdlc/incidents/`、新 intent | `bands.yaml` 是确定性的；分诊是人做的 |

编号文件共用 slug。从 `sdlc/templates/` 复制。`status` 是 `draft`、`accepted`、`rejected` 或 `superseded`。翻成 `accepted` **就是**闸门。

杂务（错别字、纯注释、CI yaml 小修）可以跳过 intent/spec/plan。PR 上写 `chore / no plan`。

## Skill、hook、subagent

Skill 是建议（`.agents/skills/`，经 `.claude/skills` 发现）。`.claude/settings.json` 里的 hook 是确定性的：

- `scripts/hooks/production-gate.sh` — 没有 `RELEASE_APPROVAL` 不能推 `v*` / `gh release`
- `scripts/hooks/depersonalize.sh` — Edit/Write 挡住真实 home、本地工程路径、以及 `work` 以外的真实 session 名
- `scripts/hooks/protect-oracle.sh` — `Herdr.js` 和 `tests/herdr.test.mjs` 需要 `HERDR_BAR_ALLOW_ORACLE=1`

Subagent：`verifier`（跑测试、汇报、不修），`researcher`（只读）。

这个公开 MIT 仓库没有 managed / MDM 设置。git 里的 team hook 就是上限。

## 评测

`sdlc/evals/cases/` 保护章程里的原文。`scripts/run-evals.sh` 总会检查 schema 和 `must_hold` 字符串（不需要 API key）。`.github/workflows/agent-evals.yml` 跑这一套。现场 `claude -p` **不是这次改动**：workflow 打印 `skip live evals` 并成功，有没有 `ANTHROPIC_API_KEY` 都一样。

## 维护

`scripts/detect-bands.py` 读 `bands.yaml`。检测没有模型。档位约定仍是：

- 1σ — 记录
- 2σ — 诊断
- 3σ — 提议（人誊成 intent）

当前周任务只对合成 fixture 跑检测器并打印 JSON，证明脚本还活着。它不读真实 CI 历史，也不开 GitHub issue。按档评论 / 开事故是下一出。

## 不在本仓库

Claude Security（托管扫描）和 Claude Tag（Slack 值班）是 Anthropic 企业产品。漏洞仍走 [`SECURITY.md`](../SECURITY.md)。以 GitHub issue 进来的事故走同一条 intent 路径。

## 下一出（不是这次改动）

- 有 `ANTHROPIC_API_KEY` 时对评测 case 跑现场 `claude -p`；缺 key 仍 skip，不打红默认 CI。
- 有 key 之后，对失败的 CI 日志做只读 `claude -p`。
- 周任务读真实 `validate` 结论，按档写诊断或按 `sdlc/templates/incident.md` 开 bug。
- 仓库超过一名维护者时，再上 CODEOWNERS / `main` 分支保护。
