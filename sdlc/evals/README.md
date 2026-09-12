# 评测

`sdlc/evals/cases/` 里的 case 保护 `AGENTS.md`（以及具名 skill）里的原文。它们首先是结构套件。

## 结构（总会跑）

`scripts/run-evals.sh` 检查每条 case 有 `id`、`prompt`、`must_hold`（`file` + `text`）。每条 `text` 必须在被引用文件里原样出现。不需要 API key。找不到就 exit 1。

`.github/workflows/agent-evals.yml` 在碰到章程 / 评测 / hook 的 PR 上、以及每周 cron 上跑这个脚本。

## 现场（`claude -p`）

这次改动不跑现场评测。workflow 打印 `skip live evals` 并成功。接上 `ANTHROPIC_API_KEY` 之后的 `claude -p` 是下一出；到时缺 key 仍应 skip，不要打红默认 CI。

## 加一条 case

复制现有 JSON。`must_hold.text` 必须从被引用文件抄原文，不要改写。事故被接受之后，加一条本来能抓住它的 case。
