---
name: test-reload
description: After herdr-bar code changes, run tests then rebuild, install, and restart the live menu extra. Use when the user wants to see local changes in HerdrBar.app, asks to 一键更新 / reload the bar, or after MacBar / HerdrCore / glance edits. Source is not the running extra.
---

# Test then reload the extra

The working tree is not `~/Applications/HerdrBar.app`. `swift test` / `swift run` leave the installed extra on the previous binary. After a visual or protocol change the user can see, reload.

## When

- Menu-bar extra, dashboard, settings, or HerdrCore behavior changed and the user should see it.
- User asks to update / reload / 装上 / 重启 herdr-bar.
- Do **not** use for docs-only, comment-only, or test-only edits.

## Do

1. Finish the code change.
2. Run from the repo root (this is the one-shot):

   ```bash
   ./scripts/reload.sh
   ```

   Default path: `swift test` → `scripts/install.sh` (release) → kill every `MacBar` → `open ~/Applications/HerdrBar.app`.

3. If this turn **already** ran `swift test` and it passed:

   ```bash
   ./scripts/reload.sh --skip-tests
   ```

4. If the change also touches `Herdr.js` / the Node oracle:

   ```bash
   ./scripts/reload.sh --all-tests
   ```

5. Tell the user the extra was replaced, and what to glance (press highlight, chips, dashboard). Do not claim the live extra is updated until the script prints `Reloaded`.

## Do not

- `open` the old bundle without `install.sh`.
- Leave `scripts/dev-run.sh` running — reload kills every `MacBar` (installed extra **and** `swift run`).
- Skip tests after extra / glance / layout changes. `--skip-tests` is only when tests already passed this turn.
- Treat `.build/debug/MacBar` as the menu extra. The live binary is `~/Applications/HerdrBar.app/Contents/MacOS/MacBar`.
