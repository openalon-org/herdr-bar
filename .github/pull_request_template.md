## Summary

- What changed?
- Why?
- Plan: link to `sdlc/plan/NNNN-slug.md` or `chore / no plan`
- [`REVIEW.md`](../REVIEW.md) passes considered

## Testing

- [ ] `swift test`
- [ ] `node --test tests/herdr.test.mjs tests/changelog.test.mjs tests/sdlc.test.mjs`
- [ ] Extra / core UI: `./scripts/reload.sh` (or `--demo`) and I checked the menu bar / dashboard

## Docs

- [ ] No user-facing change, **or**
- [ ] `README.md` and `docs/guide/` (English + `docs/zh/`) match the new behavior
- [ ] User-facing change is listed in [`CHANGELOG.md`](../CHANGELOG.md) **or** this is not a release PR (changelog is written when tagging)

## Checklist

- [ ] Diff stays on one concern
- [ ] Behavior change includes the narrowest useful test
- [ ] No real home directory, login, hostname, local path, or real session / repo name in the tree ([`AGENTS.md`](../AGENTS.md))
