# 事故

事后分析放这里。复制 [`sdlc/templates/incident.md`](../templates/incident.md)。`status: accepted` 是人闸门。

已接受的事故变成：

1. 一份新的 `sdlc/intent/NNNN-slug.md`（同一 slug 或后续编号）。
2. `sdlc/evals/cases/` 下一条本来能抓住这次遗漏的评测。

文件保持去人格化：`/Users/me`、`/home/user`、session `work`。不要贴真实 home、登录名或机器名。

检测器是 `scripts/detect-bands.py` 加 `bands.yaml`。分诊是人做的。`.github/workflows/maintain-bands.yml` 只对合成 fixture 跑检测器。不要从这次的 CI 开 GitHub issue。
