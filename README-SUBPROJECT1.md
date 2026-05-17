# Sub-project 1: World Rendering — Eyes-On Test Guide

Manual verification that the MMO client renders the world with real sprites.

## Prereqs

See `README-M0.md`. On Apple Silicon, native binaries are built with
`./build_native.sh` (the `hl` JIT is unavailable on ARM Macs). On Windows,
use `.\build_native.ps1` or the `hl` JIT via the `run-*.ps1` scripts.

## Setup

```bash
./build_native.sh                                 # build everything
./bin/server-cli create-account tester hunter2    # if no account yet
```

## Launch

Terminal 1 — server (wait for `listening on 127.0.0.1:7778`; the zone
re-parses the 1024x1024 map, ~30s):

```bash
./run-server.sh
```

Terminal 2 — client:

```bash
./run-client.sh
```

## What to verify

- [ ] Log in as `tester` / `hunter2`. After the connecting screen, the world
      renders as **real pixel-art terrain** — grass, water, sand, dirt, stone,
      rock, trees, flowers, lava, cactus — not flat colored rectangles.
- [ ] The view fills the window (default 1280x960, an exact 4x of the 320x240
      render buffer) with no black bars and no seam lines between tiles.
- [ ] Your player renders as the **animated player sprite**, not a square.
- [ ] WASD / arrow keys move the player one tile per server tick; the player
      **faces the direction of travel** and the **walk animation** plays. The
      side-facing sprite mirrors for left vs. right.
- [ ] The world scrolls to keep the player centered.
- [ ] Open a second client with a second account — both players see each other
      as animated sprites, moving smoothly.

## Notes

- Terrain is flat (one sprite per tile, no neighbour blending) — hard tile
  edges are expected; blending is deferred to a later sub-project.
- Lighting is full-bright — no day/night, no light sources.
- Movement speed (one tile per 200 ms) is server-authoritative gameplay
  tuning, not a rendering concern.
