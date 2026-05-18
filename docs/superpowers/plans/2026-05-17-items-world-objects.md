# Items + World Objects — Implementation Plan

**Date:** 2026-05-17
**Design:** `docs/superpowers/specs/2026-05-17-items-world-objects-design.md`
**Sub-project:** 2 of 5

Seven tasks, each ending green (build + tests) and in its own commit.

## File Structure

**New files:**

- `shared/src/shared/item/ItemCategory.hx` — RESOURCE / TOOL / FURNITURE.
- `shared/src/shared/item/ItemType.hx` — the catalog (Task 1).
- `shared/test/TestItemCatalog.hx` — catalog tests (Task 1).
- `shared/src/shared/proto/MsgGroundItemSpawn.hx` — wire message (Task 2).
- `shared/src/shared/proto/MsgWorldObjectSpawn.hx` — wire message (Task 2).
- `server/src/server/zone/GroundItem.hx` — server ground-item entity (Task 3).
- `server/src/server/zone/WorldObject.hx` — server furniture entity (Task 3).
- `server/src/server/zone/WorldPopulator.hx` — deterministic placement (Task 3).
- `server/test/TestWorldPopulator.hx` — placement/collision tests (Task 3).
- `client/src/client/render/GroundItemVisual.hx` — client ground-item (Task 6).
- `README-SUBPROJECT2.md` — eyes-on guide (Task 7).

**Modified files:**

- `shared/src/shared/proto/MsgType.hx` — 2 new ids (Task 2).
- `shared/test/TestMain.hx` — register `TestItemCatalog` (Task 1).
- `shared/test/TestMessages.hx` — round-trip the 2 new messages (Task 2).
- `server/src/server/zone/ZoneSimulator.hx` — hold items/objects; unified
  walkability predicate (Task 3).
- `server/src/server/zone/Main.hx` — populate the zone at boot (Task 3).
- `server/src/server/zone/EnterZoneHandler.hx` — spawn-burst the items/objects
  to a joining client (Task 4).
- `server/test/TestZoneSimulator.hx` — object-blocks / item-doesn't (Task 3).
- `client/src/client/render/SpriteCatalog.hx` — item/furniture sprites (Task 5).
- `client/test/TestSpriteCatalog.hx` — item completeness check (Task 5).
- `client/src/client/render/ZoneRenderer.hx` — item/object draw passes (Task 6).
- `client/src/client/Main.hx` — dispatch the 2 new messages (Task 6).

## Task 1: Item catalog (`shared.item`)

- **Step 1:** `ItemCategory` — `enum abstract ItemCategory(Int)` with
  `RESOURCE`, `TOOL`, `FURNITURE`.
- **Step 2:** `ItemType` — an `enum abstract ItemType(Int)` over a stable
  integer id, with companion data tables: `name(id)`, `category(id)`,
  `stackable(id)`, and `ALL` (every member). Ids are grouped:
  resources `1–21`, tools `30–54` (5 ToolType × 5 tier; name = "`<Tier> <Type>`"),
  furniture `60–65`. Reserve gaps so later sub-projects extend without
  renumbering. Resources/furniture `stackable = true` for resources, tools and
  furniture `false`.
- **Step 3:** `TestItemCatalog` — 21 resources, 25 tools, 6 furniture; ids
  unique; furniture members report `FURNITURE`; `ALL.length == 52`.
- **Step 4:** register in `shared/test/TestMain.hx`; `make`-build shared-test,
  run, confirm green (was 119 → now 119 + new).
- **Step 5:** commit `feat(items): item catalog (shared.item)`.

## Task 2: Protocol messages

- **Step 1:** `MsgType` — add `GROUND_ITEM_SPAWN = 30`, `WORLD_OBJECT_SPAWN = 31`.
- **Step 2:** `MsgGroundItemSpawn` — `{ worldItemId:Int, itemTypeId:Int,
  count:Int, tileX:Int, tileY:Int }`; `MsgWorldObjectSpawn` —
  `{ objectId:Int, objectTypeId:Int, tileX:Int, tileY:Int }`. Both use the
  `@:build(SerializableMacro.build())` + `implements Serializable` pattern of
  `MsgEntitySpawn`.
- **Step 3:** `TestMessages` — serialize→deserialize round-trip for both.
- **Step 4:** build shared-test, run, confirm green.
- **Step 5:** commit `feat(proto): ground-item + world-object spawn messages`.

## Task 3: Zone world entities, placement & collision

- **Step 1:** `GroundItem` — `{ id, itemType:ItemType, count, tileX, tileY }`;
  `WorldObject` — `{ id, objectType:ItemType, tileX, tileY }`.
- **Step 2:** `ZoneSimulator` — add `groundItems:Array<GroundItem>` and
  `worldObjects:Array<WorldObject>` with accessors. Add
  `objectAt(x,y):Bool`. Replace the inline walkability test in `tick()` with
  one predicate: `canStep(x,y) = map.isWalkable(x,y) && entityAt(x,y)==null &&
  !objectAt(x,y)`. Ground items never block.
- **Step 3:** `WorldPopulator.populate(sim)` — deterministic. World objects:
  one of each of the 6 furniture types at fixed tiles forming a camp a few
  tiles off `Constants.DEFAULT_SPAWN_X/Y` (skip non-walkable tiles via
  `findWalkableNear`). Ground items: a seeded `engine`-free RNG scatters ~40
  items of assorted resource types across walkable tiles within a radius of
  spawn. Stable ids: objects `1..`, items `1..`.
- **Step 4:** `zone/Main.hx` — call `WorldPopulator.populate(sim)` after the
  map loads, before the server loop.
- **Step 5:** tests — `TestZoneSimulator`: a `WorldObject` tile blocks a
  queued move, a `GroundItem` tile does not. `TestWorldPopulator`: populate
  twice → identical layouts; every object/item sits on a walkable tile; ids
  unique.
- **Step 6:** build + run server-test (needs DB) — confirm green.
- **Step 7:** commit `feat(zone): ground items + world objects with collision`.

## Task 4: Zone spawn-burst on entry

- **Step 1:** `EnterZoneHandler.handle` — after the existing player
  `MsgEntitySpawn` sync loop, send the joining `conn` one
  `MsgWorldObjectSpawn` per `sim.worldObjects` and one `MsgGroundItemSpawn`
  per `sim.groundItems`.
- **Step 2:** extend `HeadlessClient` (test harness) to collect the new spawn
  frames during `enterZone()`, so `TestZoneLifecycle` can assert counts.
- **Step 3:** `TestZoneLifecycle` — after `enterZone()`, assert the client
  received the expected object/item counts.
- **Step 4:** build + run server-test — confirm green.
- **Step 5:** commit `feat(zone): broadcast items + objects on zone entry`.

## Task 5: Client `SpriteCatalog` — item & furniture sprites

- **Step 1:** confirm the item sprite sheet under `res/sprites/` (legacy
  `SpriteNames.itemRawTile`); register it in `ZoneRenderer.loadSheets`.
- **Step 2:** `SpriteCatalog` — add `ITEM_TABLE:Map<Int,TileSprite>` keyed by
  `ItemType` id and `ALL_ITEMS`, with a cell + palette per item, cross-
  referenced from `game.SpriteNames` / legacy `Resource`/`ToolItem`/furniture
  render code. Add `itemsComplete()`.
- **Step 3:** `TestSpriteCatalog` — every `ItemType` has an `ITEM_TABLE`
  entry.
- **Step 4:** build + run client-test — confirm green (14 → 14 + new).
- **Step 5:** commit `feat(client): item + furniture sprites in SpriteCatalog`.

## Task 6: Client `ZoneRenderer` item/object passes + `Main` wiring

- **Step 1:** `GroundItemVisual` — `{ id, itemType, count, tileX, tileY }`
  (plain holder; ground items are static in SP2).
- **Step 2:** `ZoneRenderer` — load the item sheet; resolve item/furniture
  `SpriteId`s; add `addGroundItem` / `addWorldObject`; draw passes in
  `render()` after terrain, before `drawEntities()` — ground items then world
  objects. Furniture renders its 2×2 cell block; unknown ids use `drawMissing`.
- **Step 3:** `client.Main` — register `GROUND_ITEM_SPAWN` /
  `WORLD_OBJECT_SPAWN` on the zone dispatcher; handlers forward to
  `zoneRenderer`. Hold nothing else — items are static.
- **Step 4:** build the client — confirm it compiles.
- **Step 5:** commit `feat(client): render ground items + world objects`.

## Task 7: Eyes-on guide + regression

- **Step 1:** `README-SUBPROJECT2.md` — M1/SP1-style: log in; the world shows
  scattered item sprites and a furniture camp near spawn; the player walks
  over items but is blocked by furniture.
- **Step 2:** full regression — `shared-test`, `client-test`, `server-test`
  (via `run-integration`) all green; counts ≥ the pre-SP2 baseline
  (119 / 14 / 77) plus the new assertions.
- **Step 3:** commit `docs(sp2): eyes-on guide + close out sub-project 2`.

## Notes

- Server authority and the wire protocol stay M1-compatible — SP2 is purely
  additive (2 new message types, no changes to existing ones).
- `shared.item` must not import `engine` or `game`.
- Item/furniture sprite cell coordinates are a manual art-matching step
  (design §Risks); if a cell looks wrong it is a one-line `ITEM_TABLE` fix.
