---
name: depersonalize
description: Keep the published tree de-personalized with /Users/me, /home/user, and session work. Use before committing, when writing tests or docs, or when a scan might leak a real home, login, or session name.
---

# Depersonalize

The published tree is de-personalized. Tests, comments, fixtures, and docs must not contain a real home directory, login, machine hostname, local project path, or a real session / repo name.

## When

- Writing tests, fixtures, docs, skills, or eval cases.
- Before commit. After a hook blocked an Edit/Write.

## Do

1. Use roots `/Users/me`, `/home/user`, `~/…`. Named-session examples are `default` plus a generic `work`. Folder fixtures are synthetic (`alpha`, `notes`, `beta`).
2. Scan before commit with the documented grep in AGENTS.md. Hits on `/Users/me` and `/home/user` are OK.
3. Rewrite a test that only runs on one laptop against temp dirs or those fixtures.

## Do not

- Commit `/Users/<you>`, `/home/<you>` other than `user`, local project paths, or a session name other than `default` / `work`.
- Weaken `scripts/hooks/depersonalize.sh` to let a real path through.
