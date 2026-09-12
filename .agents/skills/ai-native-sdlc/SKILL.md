---
name: ai-native-sdlc
description: Route herdr-bar work through intent then spec then plan then PR then a human tag. Use on any feature, product bug, incident, or delivery question. Do not skip gates for non-trivial work.
---

# AI-native SDLC

Non-trivial work in this repo follows [`sdlc/README.md`](../../../sdlc/README.md). Session commands live in [`CLAUDE.md`](../../../CLAUDE.md). Review passes live in [`REVIEW.md`](../../../REVIEW.md). Product behavior still lives in [`AGENTS.md`](../../../AGENTS.md). Human-facing files under `sdlc/` (templates, numbered artifacts, runbooks, eval/incident READMEs) are Chinese. Agent-facing `CLAUDE.md`, skills, `REVIEW.md`, and eval prompts stay English.

```text
intent (accepted) -> spec (approved) -> plan (engineer accepts)
  -> code + tests -> PR + REVIEW.md -> tag / zip (human)
  -> band breach / incident -> new intent
```

## When

- A feature, product bug, incident, or delivery question.
- The user asks how work ships, who gates a change, or where intent/spec/plan live.
- Do **not** use this skill to invent extra / HerdrCore behavior. Invariants stay in `AGENTS.md`.

## Do

1. Start at `capture-intent` unless an accepted `sdlc/intent/NNNN-slug.md` already exists.
2. Humans flip `status: accepted` on intent, spec, and plan. That **is** the gate. Do not treat a draft as permission to edit `Sources/`.
3. After the plan is accepted, implement and keep the plan file in the same commit if the work diverges.
4. Open a PR. Fill `.github/pull_request_template.md`. Point at `sdlc/plan/NNNN-slug.md` or write `chore / no plan`.
5. Stop at the tag. A human publishes `v*`. Do not tag without `RELEASE_APPROVAL`.

## Do not

- Skip intent/spec/plan for non-trivial work. Typos, comment-only, and CI yaml nits may skip — say `chore / no plan` on the PR.
- Move invariants into `CLAUDE.md`.
- Pretend hosted security scans or Slack on-call products exist in this public MIT extra.
