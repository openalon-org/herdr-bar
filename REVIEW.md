# Review

Claude and humans use the same passes. Findings do not merge a PR. Branch protection / a maintainer still approves. The agent that wrote the diff cannot approve it.

## Passes

Tag every finding.

- **Bugs** — logic errors, edge cases, silent failures, regressions against `sdlc/plan/` and existing tests.
- **Security** — unexpected process control, local data exposure, credentials in the tree, network listeners (this extra must not grow one), raising `herdr server`.
- **Compliance** — the change matches `sdlc/spec/`, `sdlc/plan/`, and [`AGENTS.md`](AGENTS.md). Extra / core UI ran `scripts/reload.sh` when the user should see it. Docs twins exist. Tree stays de-personalized.

## Important vs Nit

**Important:** would break behavior, leak a real home/login/session name, violate an invariant, skip the production tag gate, or ship without the tests named in the plan.

**Nit:** naming, comment wording, import order. At most five nits per review; summarize the rest as a count.

## Do not report

- Generated / build trees: `.build/`, `docs/.vitepress/dist/`, `docs/.vitepress/cache/`, `node_modules/`, `WidgetExtension/*.xcodeproj/xcuserdata/`.
- Anything CI already enforces (`swift test`, Node oracle, changelog extractor, `tests/sdlc.test.mjs`, VitePress build, SEO tests).
- Changelog absences on process-only PRs.

## Evidence

Paste the test command output. Link `sdlc/plan/NNNN-slug.md` (or write `chore / no plan`).
