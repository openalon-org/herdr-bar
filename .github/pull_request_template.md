## Summary

- What changed?
- Why?

## Testing

- [ ] `swift test`
- [ ] `node --test tests/herdr.test.mjs`
- [ ] Extra / core UI: `./scripts/reload.sh` (or `--demo`) and I checked the menu bar / dashboard

## Docs

- [ ] No user-facing change, **or**
- [ ] `README.md` and `docs/guide/` (English + `docs/zh/`) match the new behavior

## Checklist

- [ ] Diff stays on one concern
- [ ] Behavior change includes the narrowest useful test
- [ ] No real home directory, login, hostname, local path, or real session / repo name in the tree ([`AGENTS.md`](../AGENTS.md))
