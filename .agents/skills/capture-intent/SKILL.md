---
name: capture-intent
description: Write sdlc/intent/NNNN-slug.md from the originators words and leave it draft until accepted. Use when starting a feature, product bug, or incident, or when the user describes a problem that is not yet an intent file.
---

# Capture intent

Copy [`sdlc/templates/intent.md`](../../../sdlc/templates/intent.md). Pick the next unused `NNNN`. Keep the originators wording. `status` stays `draft` until the originator and a maintainer accept.

## When

- The user describes a problem, outcome, or incident that is not already `sdlc/intent/NNNN-slug.md`.
- An accepted GitHub issue is ready to transcribe (put the issue number in frontmatter `issue`).

## Do

1. List `sdlc/intent/` and choose the next four-digit `NNNN`.
2. Copy the template. Fill the Chinese headings (问题, 预期结果, 影响的用户与系统, 约束, 未决问题). Human-facing `sdlc/` bodies are Chinese; keep frontmatter keys in English.
3. Constraints include `AGENTS.md` unless the intent explicitly asks to change one.
4. Leave `status: draft`. Tell the originator the file path. Do not start a spec until `status: accepted`.

## Do not

- Invent requirements the originator did not say.
- Start `sdlc/spec/` or edit `Sources/` from a draft intent.
- Put a real home, login, local project path, or session name other than `work` in the file.
