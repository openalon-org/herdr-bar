---
outline: false
description: How herdr-bar turns an accepted intent into a tagged zip, and where humans sit at the gates.
---

# Delivery loop

Non-trivial work in this repo follows a committed loop. Chat is not the source of truth. The playbook lives in [`sdlc/README.md`](https://github.com/openalon-org/herdr-bar/blob/main/sdlc/README.md) (Chinese; that is the human copy). Product behavior still lives in [`AGENTS.md`](https://github.com/openalon-org/herdr-bar/blob/main/AGENTS.md).

```text
intent (accepted) -> spec (approved) -> plan (engineer accepts)
  -> code + tests -> PR + REVIEW.md -> tag / zip (human)
  -> band breach / incident -> new intent
```

Typos, comment-only, and CI yaml nits may skip the artifacts. Say `chore / no plan` on the PR.

## Gates

Humans flip `status: accepted` on intent, spec, and plan. That **is** the gate. A draft is not permission to edit `Sources/`. A human still merges the PR and pushes `v*`. An agent session cannot pass the tag gate without `RELEASE_APPROVAL`.

## Artifact paths

| Stage | Writes |
|---|---|
| Plan | `sdlc/intent/NNNN-slug.md` |
| Design | `sdlc/spec/NNNN-slug.md` |
| Build | `sdlc/plan/NNNN-slug.md`, then the diff |
| Test | `sdlc/evals/` |
| Ship | PR; GitHub Release zip |
| Maintain | `sdlc/incidents/` |

Numbered files share a slug. Copy `sdlc/templates/`. Rollback is install the previous zip (`sdlc/runbooks/rollback-release.md`).

## Skills vs hooks

Skills under `.agents/skills/` are advisory (`ai-native-sdlc`, `capture-intent`, `requirements-design`, `plan-mode`, `depersonalize`). Hooks in `.claude/settings.json` are deterministic: no `v*` push without approval, no real home in Edit/Write, no silent edit of `Herdr.js`.

## Evals and bands

`scripts/run-evals.sh` always checks that each case still finds its `must_hold` phrase. Live `claude -p` is a next play; the workflow prints `skip live evals` even when a key exists.

`scripts/detect-bands.py` reads `bands.yaml`. Detection has no model. The weekly job runs the detector on synthetic fixtures and prints the tier. It does not open GitHub issues. 1σ log, 2σ diagnose, 3σ propose remain the contract for a later play. Triage is human.

## Not in this repo

Hosted security scans and Slack on-call are enterprise products. Vulnerabilities still go through [`SECURITY.md`](https://github.com/openalon-org/herdr-bar/blob/main/SECURITY.md). Incidents that arrive as GitHub issues follow the same intent path.
