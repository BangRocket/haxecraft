# CI + Headless Bots — Design (M2 sub-project 3)

**Date:** 2026-05-18
**Status:** Approved (design)
**Milestone:** M2 — Multiple players in one zone. Sub-project 3 of 3 (the
final piece; SP1 interest management and SP2 chat + emotes are done).

## Context

M2 made one zone hold many players — interest-managed entity visibility
(SP1) and chat (SP2). What's missing is *confidence at scale and over time*:
there is no continuous integration, and no way to put many players in a zone
to exercise it. SP3 adds both.

`HeadlessClient` (the test harness) already drives the whole protocol —
login, enter zone, move, chat, drain frames — so it is the foundation for
bots. The repo has **no CI** (`.github/` is absent).

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| CI coverage | Linux **and** Windows |
| Headless bots | A standalone bot-runner tool **and** a CI multi-player smoke test |
| Bot behaviour | Wander + chat + gather |

## Section 1 — Continuous integration

A GitHub Actions workflow (`.github/workflows/ci.yml`), triggered on push
and pull request, with two jobs:

- **`linux`** (ubuntu-latest) — the full suite. Installs Haxe + the
  haxelibs, builds HashLink 1.15 from source, brings up MySQL (an Actions
  service container), applies migrations, builds every target, and runs
  `shared-test`, `client-test`, `server-test`, and the **headless-bot
  multi-player smoke test** (Section 3).
- **`windows`** (windows-latest) — the build + pure-unit guard. Installs
  Haxe + the haxelibs, unzips the HashLink Windows release, builds every
  target, and runs `shared-test` + `client-test`. It does **not** run
  `server-test` or bots: GitHub's MySQL service container is Linux-only, and
  standing MySQL up on a Windows runner is not worth the complexity. The
  Windows job's job is to catch Windows build regressions (the project ships
  on Windows) — the integration coverage lives in the Linux job.

The client is *built* on CI (compiling to `.hl` needs no display) but never
*run* graphically. Server integration runs headless.

## Section 2 — The bot-runner tool

A new `tools/zone-bots/` Haxe program. Given `--count N` and
`--duration S`, it:

- Ensures `N` bot accounts exist (`bot_0` … `bot_{N-1}`), creating any
  missing ones via `AccountDal` + `PasswordHash` against the database.
- Spawns one OS thread per bot (`sys.thread.Thread`). Each bot runs a
  `HeadlessClient`: connect to the gateway, log in, enter the zone, then
  loop a behaviour step until the duration elapses.
- Tallies per-bot action counts and errors, prints a summary, and exits
  non-zero if **any** bot raised an error — so CI can assert on it.

## Section 3 — Bot behaviour & the CI smoke test

Each step a bot picks a weighted-random action:

- **Wander** — `move` in a random direction. Exercises movement, the zone
  tick, and interest management.
- **Chat** — `sendChat` a canned line on a random channel. Exercises M2 SP2.
- **Gather** — `useItemOnTile` on an adjacent tile with the active tool
  (bots start with the wood tool kit). Exercises SP4 gathering.

`HeadlessClient` gains the two calls bots need that it lacks —
`useItemOnTile` and `selectActiveSlot`.

The **CI smoke test** is the bot-runner itself: the Linux job, with the
gateway + zone already running, launches a handful of bots for a short
duration. Success = the tool exits zero (every bot connected, entered the
zone, and ran its behaviour loop without error). This is an automated
multi-player end-to-end check — many clients in one zone at once.

## Testing & error handling

- `client-test` gains a `HeadlessClient` smoke check where practical
  (pure-logic parts); the live bot run is the real multi-client test.
- The existing shared/client/server suites must stay green — SP3 is
  additive (a tool + a workflow; no protocol or schema change).
- A bot that loses its connection records the error and stops cleanly
  rather than hanging; the runner still reports and exits.

## Sub-project boundary

M2 is complete when CI builds and tests the project on Linux and Windows on
every push, and a headless-bot run can put many players into one zone —
wandering, chatting and gathering — as both a manual load tool and an
automated CI smoke test.
