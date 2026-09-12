# herdr-bar

Product constitution: [`AGENTS.md`](AGENTS.md). Delivery loop: [`sdlc/README.md`](sdlc/README.md). Review contract: [`REVIEW.md`](REVIEW.md).

## Commands

```bash
swift test
node --test tests/herdr.test.mjs tests/changelog.test.mjs tests/sdlc.test.mjs
./scripts/reload.sh              # extra / HerdrCore the user should see
./scripts/reload.sh --skip-tests # this turn already passed swift test
./scripts/dev-run.sh --demo      # fixture extra; does not replace the installed app
npm run docs:dev
npm run docs:build
```

Healthy: `swift test` prints `Test run with … tests in … passed`; Node prints `# fail 0` and exits 0. `reload.sh` prints `Reloaded ~/Applications/HerdrBar.app`. Do not claim the live extra matches the tree until that line appears.

Run the test commands and paste the output before reporting a task complete. If a test fails, fix the code, not the test. Bug fixes: write the failing test first.

## Architecture

- `Sources/HerdrCore` — protocol, discovery, aggregation, focus raising, widget snapshot.
- `Sources/MacBar` — menu extra and dashboard. Writes `~/.config/herdr/widget-snapshot.json`.
- `Sources/HerdrWidget` — WidgetKit source; the gallery `.appex` is built from `WidgetExtension/`.
- `Herdr.js` — behavior oracle. Do not edit it or `tests/herdr.test.mjs` unless `HERDR_BAR_ALLOW_ORACLE=1`.

## Conventions

- Invariants in `AGENTS.md` *are* the product. Event-driven updates; never create a pane; glance not inventory.
- Published tree is de-personalized: `/Users/me`, `/home/user`, `~/…`, session `work`. Scan: `git grep -nE '/Users/|/home/|eden|client\.new' -- . ':!package-lock.json'`.
- User-facing history is `CHANGELOG.md` at tag time. Process and docs do not get a changelog section.
- Docs: English `docs/guide/`, Chinese `docs/zh/guide/`. New guide pages need both and a sidebar key. Human-facing `sdlc/` artifacts (templates, numbered intent/spec/plan, runbooks) are Chinese; this file, skills, and `REVIEW.md` stay English.

## Things Claude gets wrong

- `swift test` does not update `HerdrBar.app`. Reload after extra / core changes.
- Do not timer-poll `agent.list` or jsonl. Do not raise `herdr server`.
- Do not add elapsed time, token counts, or pane badges on dashboard rows.
- Do not wrap the popover list in a custom `NSScrollView`/`NSHostingView` (intrinsic height collapses).
- Do not tag `v*` or run `gh release` without `RELEASE_APPROVAL`.
