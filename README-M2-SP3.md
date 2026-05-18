# M2 Sub-project 3: CI + Headless Bots

Design: `docs/superpowers/specs/2026-05-18-ci-headless-bots-design.md`.
The final M2 sub-project — closes out *Multiple players in one zone*.

## Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request, two jobs:

- **linux** — builds HashLink from source, builds every target, runs the
  `shared`/`client`/`server` test suites, then a headless-bot multi-player
  smoke test (8 bots in one zone).
- **windows** — installs the HashLink release, builds every target, runs the
  pure-unit suites. A build-regression guard for the shipped Windows
  platform (no MySQL — GitHub service containers are Linux-only).

CI status is on the repository's **Actions** tab.

## Headless bots

`tools/zone-bots` puts many headless players into a running zone — for load
and soak testing, and as the CI multi-player smoke test.

Build it: `make zone-bots` (or `cd tools/zone-bots && haxe build-zone-bots.hxml`).

Run it against a live server (`run-server.ps1` / `run-server.sh`):

```
hl out/zone-bots.hl --count 8 --duration 15
```

- `--count N` — number of bots (default 8). Each gets a `bot_N` account,
  created on first use.
- `--duration S` — seconds to run (default 15).

Each bot connects through the gateway, enters the zone, and loops a
weighted-random behaviour — **wander** (movement + interest management),
**chat** (M2 SP2), **gather** (SP4 tile interaction). The runner prints a
per-bot action/error summary and exits non-zero if any bot errored, so CI
can assert on it.

## Notes

- The bots are deliberately blocking (each `move` waits for its ack), so
  per-bot throughput is modest — the tool's value is *concurrency* (many
  clients in one zone), not raw action rate.
- The Linux CI job builds HashLink 1.15 from source; if a HashLink build
  dependency package name drifts, the `Install HashLink build dependencies`
  step is the one to adjust.
