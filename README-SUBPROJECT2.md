# Sub-project 2: Items + World Objects — Eyes-On Test Guide

Manual verification that the MMO world is populated with rendered items and
furniture. Design: `docs/superpowers/specs/2026-05-17-items-world-objects-design.md`.

## Prereqs

See `README-M0.md` / `README-WINDOWS.md`. On Windows, use the `run-*.ps1`
scripts with Haxe + HashLink + Docker Desktop installed.

## Setup

Create an account if you have none:

```powershell
docker compose up -d mysql
.\db\apply-migrations.ps1
cd server; haxe build-server-cli.hxml; cd ..
hl out\server-cli.hl create-account tester hunter2
```

## Launch

Terminal 1 — server (gateway + zone; the zone parses the 1024x1024 map and
populates it, watch for `[zone] populated: N objects, M ground items`):

```powershell
.\run-server.ps1
```

Terminal 2 — client:

```powershell
.\run-client.ps1
```

## What to verify

- [ ] Log in as `tester` / `hunter2`. The world near spawn is **scattered
      with item sprites lying on the ground** — wood, stone, coal, ore,
      gems, apples, cloth — not just bare terrain.
- [ ] A small **cluster of furniture** sits near spawn: workbench, furnace,
      oven, anvil, chest, lantern (whichever slots landed on walkable tiles).
- [ ] Walking over a ground item **passes straight through it** — items do
      not block and are not picked up (pickup is sub-project 3).
- [ ] Walking into a piece of **furniture is blocked** — the player stops at
      the tile in front of it, the same as hitting water or a tree.
- [ ] Item and furniture sprites are recognisable pixel art, not magenta
      placeholder blocks. (A magenta block means a sprite-cell coordinate in
      `SpriteCatalog.ITEM_TABLE` needs a one-line fix.)

## Notes

- Items and objects are **render-only** this sub-project. Picking items up
  and the inventory that holds them is sub-project 3; using furniture
  (opening a chest, crafting at a workbench) is sub-project 4.
- Placement is deterministic and server-authoritative — the zone seeds the
  same layout every boot. There is no map/TMX change.
- Furniture renders as a 16x16 (2x2) block but occupies and blocks a single
  tile, exactly as the 16x16 player sprite stands on one tile.
