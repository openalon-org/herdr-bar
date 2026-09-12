---
name: plan-mode
description: Stay read-only until sdlc/plan/NNNN-slug.md is accepted, then implement and update the plan in the same commit if the work diverges. Use after an accepted spec, before editing Sources/.
---

# Plan mode

Write `sdlc/plan/NNNN-slug.md` from [`sdlc/templates/plan.md`](../../../sdlc/templates/plan.md). Stay read-only (no `Sources/` edits) until `status: accepted`. Update the plan in the same commit if implementation diverges.

## When

- An accepted spec exists and the engineer has not accepted a plan.
- Implementation is about to start, or has already diverged from the written plan.

## Do

1. Read the accepted intent and spec. Same `NNNN` and slug.
2. Fill 改动的文件, 工作顺序, 风险, 验收. Human-facing `sdlc/` bodies are Chinese; keep frontmatter keys in English. An engineer who never saw the conversation should be able to implement from this file.
3. Leave `status: draft` until the engineer accepts.
4. After acceptance: implement. If the diff diverges, edit the plan in the **same commit**.
5. Proof commands must match [`CLAUDE.md`](../../../CLAUDE.md). Extra / core UI: `scripts/reload.sh` after tests.

## Do not

- Edit `Sources/`, `Herdr.js`, or user-facing docs until the plan is accepted.
- Leave a stale plan after the implementation changed.
- Tag `v*` from this skill. Production is a human gate.
