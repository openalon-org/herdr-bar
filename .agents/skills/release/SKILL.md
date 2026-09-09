---
name: release
description: "herdr-bar release workflow: changelog, version tag, GitHub Release zip. Use when preparing or troubleshooting a herdr-bar release."
---

# herdr-bar Release

Ship a stable extra built by CI: update `CHANGELOG.md`, merge, tag `vX.Y.Z`. `.github/workflows/release.yml` packs the universal zip and fills the GitHub Release body from that changelog section (`scripts/changelog-notes.sh`). There is no Sparkle / Developer ID / Homebrew lane.

The docs changelog page (`docs/changelog.md`, `docs/zh/changelog.md`) includes `CHANGELOG.md`, so there is no second changelog file to edit.

## Shared prep

1. **Pick the version.** Read the newest `## [X.Y.Z]` in `CHANGELOG.md` and `git describe --tags --abbrev=0`. Choose patch / minor / major from what landed; ask if the bump is unclear. Do not tag a version that is not yet a heading in `CHANGELOG.md`.

2. **Gather changes and contributors since the last tag.**

   ```bash
   git describe --tags --abbrev=0
   git log --oneline <last-tag>..HEAD --no-merges
   ```

   Keep only end-user visible changes, categorize into Added, Changed, Fixed, Removed, and build a deduplicated list of contributor `@handle`s from PR authors and linked issue reporters. If nothing is user-facing, ask whether to release anyway.

3. **Update `CHANGELOG.md`.** Add a section at the top with the new version and today's date, written as user-facing descriptions rather than raw commit messages, with inline contributor credit.

4. **Prove the extractor.**

   ```bash
   ./scripts/changelog-notes.sh X.Y.Z
   node --test tests/changelog.test.mjs
   ```

## CI-built release

5. **Branch, commit, push.** `git checkout -b release/vX.Y.Z`, stage `CHANGELOG.md` (and any version-adjacent docs), commit `Bump version to X.Y.Z`, then `git push -u origin release/vX.Y.Z`.

6. **PR and CI.** `gh pr create --title "Release vX.Y.Z"` with the changelog section in the body, then wait for `.github/workflows/ci.yml`. Fix failures until it passes.

7. **Merge.** `gh pr merge --squash --delete-branch`, then `git checkout main && git pull`.

8. **Tag the merge commit** (the tree must contain the new changelog section).

   ```bash
   ./scripts/changelog-notes.sh X.Y.Z >/dev/null
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

9. **Watch the release workflow.** `gh run watch`. Confirm https://github.com/openalon-org/herdr-bar/releases has `HerdrBar-X.Y.Z-macos.zip` and a body that matches the changelog section, plus the unzip / `xattr` hint.

`workflow_dispatch` on **Release macOS app** only uploads an Actions artifact (`0.0.0-dev`) — it does not publish.

## Changelog guidelines

Include what a user can see, feel, or interact with: new features, noticeable bug fixes (crashes, UI glitches, wrong behavior), performance the user would feel, UI/UX changes, breaking changes and removals.

Exclude internal work: setup/build/reload scripts, CI and workflow changes, docs (README, CONTRIBUTING, AGENTS.md), tests, refactors with no user-visible effect, and dependency bumps unless they fix a user-facing bug.

Write in present tense ("Add feature", not "Added feature"), grouped by Added, Changed, Fixed, Removed. Be concise and descriptive, describe what the user experiences rather than how it was implemented, and link the issue or PR when one exists. Do not invent `#N` links.

## Contributor credits

Credit the people who made each release happen.

Per-entry attribution goes after each changelog bullet: `-- thanks @user!` for a PR author, `-- thanks @reporter for the report!` for an issue reporter who is not the PR author. Core team (`openalon`) work is the baseline and gets no per-entry callout.

Every release ends with a summary section listing all contributors alphabetically by handle, core team included, each linked to their GitHub profile. The GitHub Release body is that same section (extracted, not auto-generated from commits).

```markdown
### Thanks to N contributors!

- [@user1](https://github.com/user1)
- [@user2](https://github.com/user2)
```

## Example changelog entry

```markdown
## [0.2.0] - 2026-09-09

### Added
- Gear → About compares this build to GitHub Releases and opens the latest tag ([#12](https://github.com/openalon-org/herdr-bar/pull/12)) -- thanks @contributor!

### Fixed
- Dashboard list measuring height 0 after a native scroll-view swap ([#8](https://github.com/openalon-org/herdr-bar/pull/8)) -- thanks @reporter for the report!

### Thanks to 3 contributors!

- [@contributor](https://github.com/contributor)
- [@openalon](https://github.com/openalon)
- [@reporter](https://github.com/reporter)
```
