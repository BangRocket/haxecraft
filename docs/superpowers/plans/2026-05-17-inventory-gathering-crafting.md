# Inventory, Gathering & Crafting — Implementation Plan (SP3–5)

**Date:** 2026-05-17
**Design:** `docs/superpowers/specs/2026-05-17-inventory-gathering-crafting-design.md`

Sixteen tasks across three sub-projects. Each ends green (build + tests) in
its own commit. Regression runs at each sub-project boundary.

## SP3 — Inventory + Equipment

### Task 1 — `ItemStack` + server `Inventory`
- `shared/src/shared/item/ItemStack.hx` — `{ itemType, count }`, `merge`.
- `server/src/server/zone/Inventory.hx` — slot list, `add` (stack resources,
  new slot otherwise), `removeCount`, `has`, `activeSlot`/`activeItem`.
- `shared/test/TestItemStack.hx`, `server/test/TestInventory.hx`. Register.
- Commit `feat(items): ItemStack + server Inventory`.

### Task 2 — Inventory DB persistence
- `db/migrations/0003_character_items.sql` — `character_items(character_id,
  slot, item_type_id, count)`.
- `CharacterDal` — `loadInventory(charId)`, `saveInventory(charId, inv)`.
- `server/test/TestCharacterDal.hx` — inventory round-trip.
- Commit `feat(db): persist character inventory`.

### Task 3 — Inventory protocol
- `MsgInventory` (slot list), `MsgGroundItemDespawn` (worldItemId),
  `MsgSelectActiveItem` (slot). `MsgType` 32/33/34.
- `TestMessages` round-trips. Commit `feat(proto): inventory messages`.

### Task 4 — Zone pickup + inventory wiring
- `Character` gains an `Inventory`. `EnterZoneHandler` loads it from the DB
  and sends `MsgInventory`. `ZoneSimulator.tick()` picks up a `GroundItem`
  on a mover's destination tile → inventory, despawn, broadcast.
- `MsgSelectActiveItem` handler. Inventory saved on flush + disconnect.
- `server/test/TestZoneSimulator.hx` — walk-over pickup.
- Commit `feat(zone): walk-over item pickup + inventory sync`.

### Task 5 — Client inventory screen
- `client/src/client/ui/InventoryScreen.hx` — toggled with `I`; slot grid,
  item sprites (SpriteCatalog), counts, active-slot marker.
- `client.Main` — dispatch `MsgInventory`/`MsgGroundItemDespawn`; `I` key;
  number keys select active slot (`MsgSelectActiveItem`).
- Build client. Commit `feat(client): inventory screen`.
- **Regression: shared/client/server suites green.**

## SP4 — Interactive / Gathering Tiles

### Task 6 — TileType expansion + MapData data layer
- `TileType` — add `IRON_ORE, GOLD_ORE, GEM_ORE, HARD_ROCK, FARMLAND,
  WHEAT, TREE_SAPLING, CACTUS_SAPLING, HOLE` (ids 11..19). `isWalkable`.
- `MapData` — parallel `data:Bytes` layer; `tileData`/`setTileData`.
- `shared/test/TestTileType.hx`, `TestMapData.hx`. Commit
  `feat(world): interactive tile types + per-tile data`.

### Task 7 — Worldgen ore + client tile sprites
- `tools/worldgen-tmx` — scatter `IRON_ORE`/`GOLD_ORE`/`GEM_ORE` in rock
  regions, `HARD_ROCK` pockets. `make regenerate-map`.
- `SpriteCatalog.TILE_TABLE` + `ZoneRenderer` — sprites for the 9 new tiles
  and wheat growth stages (keyed on the data byte).
- Commit `feat(worldgen): ore tiles; client renders interactive tiles`.

### Task 8 — Tile interaction protocol
- `MsgUseItemOnTile` (tileX, tileY), `MsgTileChange` (tileX, tileY,
  tileType, data). `MsgType` 35/36. `TestMessages`.
- Commit `feat(proto): tile interaction messages`.

### Task 9 — Zone tile interaction + growth
- `server/src/server/zone/TileInteraction.hx` — tool→tile rules, damage
  accumulation, mutation, drops (exact parity counts), planting.
- `ZoneSimulator.tick()` — growth: saplings→tree/cactus, wheat ageing,
  grass spread; bounded to an active region around players.
- `MsgUseItemOnTile` handler; broadcast `MsgTileChange`; drops become
  `GroundItem`s. `server/test/TestTileInteraction.hx`.
- Commit `feat(zone): tile gathering, drops, growth`.

### Task 10 — Tile-override persistence
- `db/migrations/0004_zone_tile_overrides.sql` —
  `zone_tile_overrides(x, y, tile_type, data)`.
- A `ZoneTileDal`; the zone loads overrides at boot and applies them;
  mutations upsert; periodic flush.
- `server/test` round-trip. Commit `feat(db): persist zone tile edits`.

### Task 11 — Client tile interaction
- `client.Main` / `InputDispatcher` — send `MsgUseItemOnTile` (use the
  active item on the tile the player faces); apply `MsgTileChange`.
- `ZoneRenderer` — re-render changed tiles.
- Build client. Commit `feat(client): tile interaction`.
- **Regression green.**

## SP5 — Crafting

### Task 12 — Recipe catalog
- `shared/src/shared/item/CraftStation.hx` (WORKBENCH/ANVIL/FURNACE/OVEN),
  `Recipe.hx`, `RecipeBook.hx` — the 37 legacy recipes as data.
- `shared/test/TestRecipeBook.hx`. Commit `feat(items): recipe catalog`.

### Task 13 — Crafting protocol
- `MsgCraft` (recipeId), `MsgPlaceFurniture` (tileX, tileY). `MsgType`
  37/38. `TestMessages`. Commit `feat(proto): crafting messages`.

### Task 14 — Zone crafting + furniture placement
- `server/src/server/zone/Crafting.hx` — proximity-to-station check,
  validate + consume inputs, produce output to inventory.
- `MsgCraft` + `MsgPlaceFurniture` handlers; placement creates a persisted
  `WorldObject`. `server/test/TestCrafting.hx`.
- Commit `feat(zone): crafting + furniture placement`.

### Task 15 — Client crafting screen
- `client/src/client/ui/CraftingScreen.hx` — opened with `C` near a
  station; recipe list with input-availability; craft on Enter; furniture
  place-mode.
- `client.Main` wiring. Build client. Commit `feat(client): crafting screen`.

## Close-out

### Task 16 — Eyes-on guides + final regression
- `README-SUBPROJECT3.md`, `README-SUBPROJECT4.md`, `README-SUBPROJECT5.md`.
- Full regression: shared / client / server suites green.
- Commit `docs: close out the content arc (SP3-5)`.

## Notes

- Protocol additions are append-only `MsgType` ids; no existing message
  changes. DB additions are new tables (migrations 0003, 0004).
- No player stamina/health — interactions need only the correct tool type;
  tool tier scales mined-tile damage.
- Growth ticking is bounded to tiles near connected players to keep the
  1024x1024 map cheap.
