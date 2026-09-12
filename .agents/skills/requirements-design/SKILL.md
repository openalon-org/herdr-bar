---
name: requirements-design
description: Refuse unless the matching intent is accepted, then write sdlc/spec/NNNN-slug.md and flag AGENTS.md contradictions. Use after capture-intent, before plan-mode.
---

# Requirements and design

Refuse if the matching intent is missing or not `status: accepted`. Copy [`sdlc/templates/spec.md`](../../../sdlc/templates/spec.md). Flag contradictions with [`AGENTS.md`](../../../AGENTS.md) instead of papering over them.

## When

- An accepted `sdlc/intent/NNNN-slug.md` exists and Design has not landed.
- The user asks what must be true when this ships.

## Do

1. Read the accepted intent and `AGENTS.md` first.
2. Copy the template. Same `NNNN` and slug as the intent.
3. Numbered 需求 each trace to the intent. Human-facing `sdlc/` bodies are Chinese; keep frontmatter keys in English.
4. 设计 says how it fits the existing tree: types, files, user-visible behavior, docs locales.
5. 风险 / 顾虑: name the owner of each flag. If a requirement contradicts an invariant, **flag it** and stop — do not rewrite `AGENTS.md` in the spec.
6. Leave `status: draft` until a maintainer accepts.

## Do not

- Write a spec from a draft or missing intent.
- Hide an invariant clash in Design prose.
- Start `Sources/` edits. That waits for an accepted plan.
