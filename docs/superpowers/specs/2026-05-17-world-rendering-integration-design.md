# World Rendering Integration + Passive Terrain — Design

**Date:** 2026-05-17
**Status:** Approved (design); pending implementation plan

## Context

The project has two clients:

- **Original haxecraft** (`src/`, ~7,350 lines) — a complete Minicraft port with
  a Heaps-based pixel-art renderer (`engine.gfx`: `Screen`, `GpuRenderer`,
  `SpriteRegistry`, sprite-atlas, palette-shifting, lighting), real sprite sheets
  under `res/sprites/`, plus single-player tiles/entities/crafting/menus.
- **MMO client** (`client/`, ~770 lines) — the M1 client. Server-authoritative,
  draws solid-color rectangles via `h2d.Graphics`, 6 tile types, networked
  entities.

The goal is to make the MMO world look and feel like a real game by bringing
the original's content into it. That full effort is **too large for one spec**
and decomposes into five sequential sub-projects:

1. **World rendering integration + passive terrain** ← *this spec*
2. Items + world objects
3. Inventory + equipment
4. Interactive / gathering tiles (ore, choppable trees, farming)
5. Crafting

Each later sub-project gets its own brainstorm → spec → plan cycle. Interactive
tiles were explicitly deferred to sub-project 4 because every interactive
tile's payoff (wood, ore, wheat) and input (pickaxe, hoe, seeds) is an *item* —
they depend on sub-projects 2 and 3.

## Scope of this sub-project

**In scope:** porting the rendering pipeline into the MMO client; expanding the
passive (static, stateless) terrain vocabulary; rendering terrain and player
entities with real sprites.

**Out of scope:** items, inventory, interactive/stateful tiles, crafting, menus,
day/night lighting, light sources, neighbor-blended terrain. No server-authority
or protocol changes — the server still owns the map and entity positions
exactly as in M1.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Integration depth | Bring over game systems (full arc); this spec is sub-project 1 only |
| Authority model (later sub-projects) | Server-authoritative |
| Render pipeline | Full `Screen` + `GpuRenderer` + `SpriteRegistry` + atlas + palette |
| Tile vocabulary | Expand the tile set (passive terrain only) |
| Interactive tiles | Deferred to sub-project 4 |
| Terrain rendering | Flat per-tile sprites — no neighbor blending |
| Integration approach | Promote `src/engine` to a new top-level `engine/` module |
| Lighting | Pipeline ported but run full-bright |

## Section 1 — Module restructure

`src/engine` moves to a new top-level **`engine/` module** at `engine/src/engine/...`,
matching the existing `shared/ client/ server/ tools/` module layout. After the
move, `src/` contains only `src/game/` (the legacy standalone game).

- Legacy game build (`build.hxml`, `build_macos.sh`) gains `-cp engine/src`.
- MMO client build gains `-cp ../engine/src`: `client/build-client.hxml`, and the
  `client` target in `build_native.sh` and `build_native.ps1`. Dead-code
  elimination drops engine code the client does not reference.
- `engine.gfx` is self-contained except one coupling: `engine.gfx.ChromeText`
  imports `game.SpriteNames` for a small number of font-glyph sprite IDs. Those
  IDs move into the `engine` module (or `ChromeText` accepts them as
  constructor parameters) so `engine` has **zero** dependency on `game`.

The legacy `src/game` game keeps compiling unchanged apart from the added
classpath entry; it is progressively cannibalized by later sub-projects and
eventually deleted.

## Section 2 — Client rendering pipeline

The MMO client adopts the original Heaps-based pipeline. A new **`ZoneRenderer`**
replaces the empty `client.ui.InZoneScreen` and the colored-rect
`WorldRenderer` / `EntityRenderer`. It owns:

- A `Screen` — fixed logical **320×240** buffer (40×30 tiles at 8 px/tile),
  integer-scaled to the window.
- A `GpuRenderer` — the existing h2d `TileGroup` + texture-atlas renderer,
  attached to the client's `s2d` scene.
- A `SpriteRegistry` — built once on zone entry.

**Per-frame flow:** compute scroll (`xScroll`/`yScroll`) from the local player's
interpolated position (follow-cam) → clear the `Screen` → draw visible terrain
tiles → draw entities → present via `GpuRenderer`.

The `client.game.Camera` class is **retired**. `Screen` xScroll/yScroll replaces
it; the visible-tile range is derived from scroll plus the 320×240 Screen
dimensions. Input handling (`MoveIntent`) and the networking layer are
untouched.

**Lighting:** the pipeline retains the light-overlay capability, but this
sub-project runs **full-bright** — no day/night cycle and no light sources.

## Section 3 — Tile vocabulary expansion (server)

`shared/src/shared/world/TileType.hx` grows from 6 to **10 passive tile types**:

| id | type | walkable |
|----|------|----------|
| 1 | GRASS | yes |
| 2 | SAND | yes |
| 3 | WATER | no |
| 4 | STONE | no |
| 5 | ROCK | no |
| 6 | TREE | no |
| 7 | DIRT | yes |
| 8 | FLOWER | yes |
| 9 | LAVA | no |
| 10 | CACTUS | no |

- `TileType.isWalkable()` is updated to cover all 10 types.
- `tools/worldgen-tmx/src/Main.hx` places the new tiles using the same
  noise + seeded-RNG style as the existing tree scatter: dirt patches within
  grass, scattered flowers on grass, lava pockets inside rock regions, cactus
  on sand. The TMX `<tileset>` `tilecount` attribute is updated.
  `make regenerate-map` rewrites `res/maps/starter.tmx` deterministically.
- `MapData` and `TmxParser` need no change — tile IDs are plain integers.

This is a server-side data change only. It does not alter the wire protocol or
server authority: the map is still authored offline and parsed by the zone.

## Section 4 — Sprite catalog & entity rendering

- A new **`client.render.SpriteCatalog`** registers, against the engine
  `SpriteRegistry`: one 8×8 terrain sprite per `TileType` (cells from
  `res/sprites/sprites_terrain.png`, coordinates cross-referenced from the
  legacy `game.SpriteNames` comments), and the animated player sprite from
  `res/sprites/sprites_player.png`.
- **Terrain:** flat — exactly one sprite per tile, no neighbor blending.
- **Entities:** every networked player renders with the player sprite (local
  and remote players alike). The client-side `EntityVisual` gains:
  - `facing` — derived client-side from each move's `(from → to)` delta; the
    server sends no facing data.
  - a walk-frame counter — advances while a move interpolation is in progress,
    rests on an idle frame when stationary.
- **Missing-sprite safety:** an unknown tile ID, or a tile/entity whose sprite
  is not registered, renders a visible magenta placeholder rather than crashing
  or silently skipping.

## Section 5 — Testing & error handling

**Automated tests:**

- `shared-test`: `TileType.isWalkable()` returns the correct value for all 10
  types; `SpriteCatalog` has a registered mapping for every `TileType` member
  (a completeness check over pure data — no GPU required).
- Worldgen: regenerate `starter.tmx`, assert it parses, dimensions are
  preserved, and every tile ID is within 1–10.
- Regression: the existing 104 `shared-test` and 77 `server-test` assertions
  must still pass — there is no server-authority or protocol change.

**Manual eyes-on guide** (M1-style): launch the client, confirm real terrain
sprites and an animated player replace the colored squares, and that movement
plus derived facing look correct.

**Error handling:**

- A failed sprite-sheet load (`hxd.Res.load`) fails fast with a clear message
  naming the missing file.
- Out-of-range tile IDs are caught at map-parse time and render as the magenta
  placeholder rather than crashing the renderer.

## Risks

- **Pipeline coupling.** `engine.gfx` may have subtler coupling to the original
  game than the import scan showed (e.g. via `Color` palette assumptions or
  `Screen` defaults). Mitigated by compiling the `engine` module standalone
  early in implementation.
- **Sprite-sheet coordinates.** The terrain/player cell coordinates in the
  legacy `SpriteNames` are authoritative but the MMO uses 8×8 tiles where
  Minicraft composed 16×16 tiles from four cells; picking a single
  representative cell per tile type is a manual art-matching step.
- **Screen vs. Camera retirement.** Retiring `Camera` touches input/follow-cam
  math; the interpolation logic in `EntityRenderer` must be preserved when its
  drawing is replaced.

## Sub-project boundary

This sub-project is complete when the MMO client renders the world and players
with real sprites from the original art, the terrain vocabulary is 10 passive
types placed by worldgen, and all existing automated tests still pass. Items,
inventory, interactive tiles, and crafting follow as sub-projects 2–5.
