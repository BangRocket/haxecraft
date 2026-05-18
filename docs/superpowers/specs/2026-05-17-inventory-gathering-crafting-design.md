# Inventory, Gathering & Crafting — Design (Sub-projects 3–5)

**Date:** 2026-05-17
**Status:** Approved (design)
**Sub-projects:** 3, 4, 5 of 5 — the close-out of the content arc.

## Context

SP1 gave the MMO a real renderer; SP2 populated the world with render-only
items and furniture. SP3–5 make that world *interactive*: pick items up
(SP3), gather them from the world (SP4), and turn them into new items (SP5).
The legacy single-player game is the parity reference; the MMO rebuilds each
system server-authoritatively.

These three were brainstormed and approved together. Decisions:

| Question | Decision |
|---|---|
| Inventory persistence | Persist to the database |
| World tile-edit persistence | Persist to the database |
| Build scope | Full legacy parity |
| Player stamina/health gating | **Dropped** — the MMO has no health/stamina substrate; interactions are not stamina-gated. Tool *type* requirements and tier-scaled tile damage are kept. |
| UI | Keyboard-driven menu screens, structured after legacy `ContainerMenu`/`CraftingMenu` |
| Authority | Server-authoritative throughout; the zone owns inventory, tiles, crafting |

---

# Sub-project 3 — Inventory + Equipment

## Scope

Players pick up the ground items SP2 placed, carry them in a persistent
inventory, and select an **active item** (the held tool/item — the legacy
game's `activeItem`; the MMO has no separate equipment slots).

**In scope:** server inventory model, automatic walk-over pickup, DB
persistence, inventory sync protocol, active-item selection, client
inventory screen. **Out of scope:** using items (SP4/SP5), dropping items
back out.

## Design

- **`shared.item.ItemStack`** — `{ itemType:ItemType, count:Int }`. Resources
  stack (merge by type); tools and furniture occupy one slot each.
- **Server `Inventory`** (`server.zone`) — an ordered slot list of
  `ItemStack`. `add`, `removeCount`, `has`, an `activeSlot` index.
- **Pickup** — `ZoneSimulator.tick()`, after applying a move, checks for a
  `GroundItem` on the entity's new tile; if found, it is added to the
  character's inventory and despawned (broadcast `MsgGroundItemDespawn`).
  Automatic — no intent, matching the legacy `touchItem` model.
- **Persistence** — migration `0003_character_items.sql`:
  `character_items(character_id, slot, item_type_id, count)`. `CharacterDal`
  gains load/save. Inventory is loaded on zone entry and saved on the
  existing periodic flush + on disconnect.
- **Protocol** (additive): `MsgInventory` (full slot list, sent on zone
  entry and after any change), `MsgGroundItemDespawn` (a picked-up item),
  `MsgSelectActiveItem` (client→server, choose the active slot).
- **Client** — an `InventoryScreen` toggled with `I`; renders slots, item
  sprites, counts; arrow keys / number keys pick the active slot; the active
  item shows in a corner HUD.

---

# Sub-project 4 — Interactive / Gathering Tiles

## Scope

Players use a tool on a terrain tile to gather resources: chop trees, mine
rock and ore, dig sand/dirt, hoe farmland, plant and harvest crops. Tiles
change state server-side, drop items as `GroundItem`s, and grow over time.

## Design

- **`TileType` expansion** — add the tiles parity needs:
  `IRON_ORE`, `GOLD_ORE`, `GEM_ORE`, `HARD_ROCK`, `FARMLAND`, `WHEAT`,
  `TREE_SAPLING`, `CACTUS_SAPLING`, `HOLE`. `isWalkable` updated. Worldgen
  scatters ore inside rock regions (parity with the legacy lava pockets).
- **Per-tile data byte** — growth/age/damage needs per-tile state. `MapData`
  gains a parallel `data:Bytes` layer (one byte per tile, default 0),
  `tileData(x,y)` / `setTileData`. The TMX `<data>` layer stays the type
  layer; data starts at 0 and is server-runtime state.
- **Interaction** — `MsgUseItemOnTile` (client→server: target tile + dir).
  The zone validates the active item is the right tool type for the target
  tile, accumulates damage in the tile-data byte (or applies a single-hit
  change), mutates the tile, spawns drops as `GroundItem`s, and broadcasts
  `MsgTileChange`. Tool tier scales mined damage; `HARD_ROCK` needs the gem
  pickaxe. No stamina.
- **Growth** — `ZoneSimulator.tick()` advances timers: tree/cactus saplings
  → tree/cactus after a tick threshold; wheat ages through 4 visual stages;
  grass spreads to adjacent dirt. A per-tick scan over an active region
  around players (not the whole 1M-tile map).
- **Planting** — using a plantable resource (seeds/acorn/cactus flower/etc.)
  on the matching tile converts it (farmland→wheat, grass→sapling, …).
- **Persistence** — migration `0004_zone_tile_overrides.sql`:
  `zone_tile_overrides(x, y, tile_type, data)`. Every server tile mutation
  upserts a row; the zone loads all overrides at boot and applies them over
  the parsed base map. Periodic + on-change flush.
- **Drops** — exact legacy counts/odds from the parity digest (tree → 1–2
  wood + 0–3 acorn + 10%/hit apple; rock → 1–4 stone + 0–1 coal; ore → 2–3;
  wheat by age; etc.), placed as `GroundItem`s on/around the tile.
- **Client** — `SpriteCatalog`/`ZoneRenderer` render the new tile types and
  wheat growth stages (the tile-data byte); the client sends
  `MsgUseItemOnTile`; applies `MsgTileChange`.

---

# Sub-project 5 — Crafting

## Scope

Players craft items from inventory resources at a crafting station
(furniture). Full legacy recipe set. Crafting furniture and **placing** it
into the world closes the loop SP2 opened.

## Design

- **`shared.item.Recipe`** + **`RecipeBook`** — the 37 legacy recipes as
  data: output `ItemType` (+count), input `ItemStack`s, and the station
  (`WORKBENCH`/`ANVIL`/`FURNACE`/`OVEN`). Grouped per station.
- **Crafting** — a player standing adjacent to a `WorldObject` of the
  station type may craft that station's recipes. `MsgCraft` (client→server:
  recipeId). The zone validates proximity + inputs, consumes inputs, adds
  the output to the inventory, broadcasts the updated `MsgInventory`.
- **Furniture placement** — a crafted furniture item can be placed:
  `MsgPlaceFurniture` (target tile). The zone validates the tile is empty
  and walkable, consumes the item, creates a `WorldObject` (persisted as a
  tile override / object table row), broadcasts `MsgWorldObjectSpawn`.
- **Client** — a `CraftingScreen` opened with `C` when next to a station;
  lists that station's recipes with input availability; craft on Enter.
  A place-mode for furniture items.

---

## Testing & error handling

Each sub-project: `shared-test` for catalog/recipe data, `server-test` for
inventory/tile/craft logic and DB round-trips, `client-test` for sprite and
screen data, plus the running integration suite. The existing 249 / 68 / 378
assertions stay green — all changes are additive to the wire protocol and DB
schema. Unknown ids render the magenta placeholder. Each sub-project ships an
eyes-on guide (`README-SUBPROJECT{3,4,5}.md`).

## Sub-project boundary

The content arc is complete when a player can walk the world, pick up and
carry items, gather resources from tiles with tools, and craft new items and
furniture at stations — all server-authoritative and persistent — with every
automated suite green.
