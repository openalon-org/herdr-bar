# Contributing

Thanks for looking at herdr-bar. Keep changes focused, preserve the invariants in [`AGENTS.md`](AGENTS.md), and open a pull request against `main`.

## Before you start

- Read [`AGENTS.md`](AGENTS.md) — those constraints *are* the product.
- Non-trivial work starts as `sdlc/intent/NNNN-slug.md` (see [`sdlc/README.md`](sdlc/README.md) and [the delivery-loop guide](docs/guide/sdlc.md)). Human-facing files under `sdlc/` are Chinese; frontmatter keys stay English (`status: accepted` is the gate).
- Search [existing issues](https://github.com/openalon-org/herdr-bar/issues) before filing a new one.
- Use the [bug](https://github.com/openalon-org/herdr-bar/issues/new?template=bug_report.yml) or [feature](https://github.com/openalon-org/herdr-bar/issues/new?template=feature_request.yml) form. Questions about Herdr itself belong at [herdr.dev](https://herdr.dev/).

## Setup

macOS 13+, Swift (Xcode or Command Line Tools), Node (for the oracle tests and the docs site).

```bash
git clone https://github.com/openalon-org/herdr-bar.git
cd herdr-bar
swift test
node --test tests/herdr.test.mjs tests/changelog.test.mjs tests/sdlc.test.mjs
```

Throwaway extra (does not replace `~/Applications/HerdrBar.app`):

```bash
./scripts/dev-run.sh
./scripts/dev-run.sh --demo
```

After MacBar / HerdrCore changes the user should see, replace the live extra:

```bash
./scripts/reload.sh              # swift test, then install + restart
./scripts/reload.sh --skip-tests # this round already passed
```

`swift test` does **not** update the menu-bar extra.

## Pull requests

1. Branch from latest `main`.
2. Keep the diff on one concern.
3. Behavior changes: add the narrowest useful test (`tests/HerdrCoreTests` and/or `tests/herdr.test.mjs`).
4. If install, settings, interactions, or requirements change, update `README.md` and `docs/guide/` (English and `docs/zh/`).
5. User-facing behavior belongs in [`CHANGELOG.md`](CHANGELOG.md) at release time, not in the PR unless you are cutting the tag. Do not keep a second changelog under `docs/`.
6. Do not commit real home directories, logins, hostnames, local project paths, or real session / repo names. Use `/Users/me`, `/home/user`, `~/…`, and the generic session name `work`.
7. Fill in `.github/pull_request_template.md`.

CI (`.github/workflows/ci.yml`) runs `swift test`, the Node oracle plus changelog and sdlc tests, and a VitePress build on every push and pull request.

## Releases

Maintainers follow `.agents/skills/release`: add a `## [X.Y.Z]` section at the top of [`CHANGELOG.md`](CHANGELOG.md), merge that, then push `vX.Y.Z`. The tag must match a heading. `.github/workflows/release.yml` builds a universal zip and fills the GitHub Release body from that section (`scripts/changelog-notes.sh`). The docs page includes the same file.

Manually running **Release macOS app** only uploads an Actions artifact (`0.0.0-dev`) — it does not publish.

The zip is ad-hoc signed. There is no Developer ID / notarization in this tree.

## Security

Do not file public issues for vulnerabilities. See [`SECURITY.md`](SECURITY.md).
