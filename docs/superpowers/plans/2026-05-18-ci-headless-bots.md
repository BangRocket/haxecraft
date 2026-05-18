# CI + Headless Bots — Implementation Plan (M2 SP3)

**Date:** 2026-05-18
**Design:** `docs/superpowers/specs/2026-05-18-ci-headless-bots-design.md`

Four tasks, each ending green in its own commit.

## Task 1 — `HeadlessClient` gather/select calls

- `client/src/headless/HeadlessClient.hx` — add `selectActiveSlot(slot)`
  (sends `MsgSelectActiveItem`) and `useItemOnTile(tileX, tileY)` (sends
  `MsgUseItemOnTile`). Both fire-and-forget, matching `sendChat`.
- Build `server-test` (which includes the headless harness) to confirm it
  compiles.
- Commit `feat(test): HeadlessClient gather + active-slot calls`.

## Task 2 — The `zone-bots` runner tool

- `tools/zone-bots/build-zone-bots.hxml` — `-cp src`, `-cp ../../shared/src`,
  `-cp ../../server/src`, `-cp ../../client/src/headless`, `-main Main`,
  `--hl ../../out/zone-bots.hl`.
- `tools/zone-bots/src/Bot.hx` — one bot: holds a `HeadlessClient`, a name,
  action/error counters; `run(durationS)` does connect → login → enterZone →
  behaviour loop (weighted wander / chat / gather) until the deadline,
  catching and recording any error.
- `tools/zone-bots/src/Main.hx` — parse `--count` / `--duration`; ensure
  `bot_0..bot_{N-1}` accounts via `AccountDal` + `PasswordHash`; spawn one
  `sys.thread.Thread` per bot; wait the duration; print a per-bot summary;
  `Sys.exit(1)` if any bot errored.
- `Makefile` — a `zone-bots` target.
- Build it; smoke it by hand against a running server.
- Commit `feat(tools): zone-bots headless load + smoke runner`.

## Task 3 — GitHub Actions CI

- `.github/workflows/ci.yml` — `on: [push, pull_request]`, two jobs:
  - **linux** (ubuntu-latest): apt deps; build + install HashLink 1.15 from
    source; `krdlab/setup-haxe`; `haxelib install heaps hlsdl hlopenal utest
    format`; MySQL via `services:`; apply migrations; `make all`; run
    `shared-test`, `client-test`, `server-test`; start gateway + zone and run
    `zone-bots` as the multi-player smoke (assert exit 0).
  - **windows** (windows-latest): `setup-haxe`; download + unzip the
    HashLink 1.15 Windows release; `haxelib install …`; build every target;
    run `shared-test` + `client-test`.
- A `ci-local.sh` / note so the workflow steps are reproducible locally.
- Commit `ci: GitHub Actions — Linux + Windows build and test`.

## Task 4 — Close-out

- `README-M2-SP3.md` — how to run the bot tool and read CI status; a CI
  status badge in `README.md` if one exists.
- Full regression: shared / client / server suites green; a local
  `zone-bots` smoke run green.
- Commit `docs: close out M2 (CI + headless bots)`.

## Notes

- CI installs HashLink from source on Linux (no official Linux release);
  the Windows job reuses the `hashlink-1.15.0-win.zip` release.
- The bot runner shares `server.db` (AccountDal) and `client.src.headless`
  (HeadlessClient) by classpath — it is a tool, so cross-module `-cp` is
  acceptable, as with `worldgen-tmx`.
- Bots exercise M2 (movement, interest, chat) and SP4 (gather); they need no
  new protocol — SP3 is purely additive tooling.
