# Items + World Objects — Design

**Date:** 2026-05-17
**Status:** Approved (design)
**Sub-project:** 2 of 5 (see `2026-05-17-world-rendering-integration-design.md` §Context)

## Context

Sub-project 1 gave the MMO client a real rendering pipeline: terrain and
player entities draw as pixel-art sprites through `client.render.ZoneRenderer`
+ `SpriteCatalog`, server-authoritative, 10 passive terrain types.

The world is still empty of *things*. Sub-project 2 populates it: it brings
the original game's **items** and **world objects** (furniture) into the MMO
as server-authoritative, rendered content.

The legacy game has a complete item system (`engine/src/engine/item/`,
`src/game/item/`, `src/game/entity/` furniture) but it is single-player and
coupled to `game.Player` / `engine.level.Level`. The MMO has **zero** item
code. SP2 is therefore a new, server-authoritative item system *informed by*
the legacy content — not a port of those classes.

## Scope of this sub-project

**In scope:**

- A shared, data-only **item catalog** — every item the legacy game defines,
  expressed as catalog data (no behavior).
- **Ground items** — items lying in the world as server-owned, rendered
  entities. Non-blocking (you walk over them).
- **World objects** — furniture (workbench, furnace, oven, anvil, chest,
  lantern) as server-owned, rendered entities. Blocking (they stop movement).
- Server placement of both at zone start; protocol to tell the client; client
  rendering through the SP1 pipeline.

**Out of scope:** picking items up, inventory, equipment, *using* items,
crafting, furniture interaction (opening a chest, crafting at a workbench),
player-driven placement, item drops from mining/combat, day/night, lighting.
No change to terrain, the map format, or M1 player-entity behavior.

Items render but cannot be touched; objects render and block but cannot be
used. Pickup + inventory is SP3; object interaction is SP4; crafting is SP5.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| How interactive in SP2 | Items & objects **render only** — pickup/use deferred |
| World objects | **Pre-placed, collidable** props; interaction → SP4 |
| Item catalog breadth | **Full catalog** defined up front as data |
| Placement | **Server-spawned**, deterministic — no map-format change |
| Authority | Server-authoritative — the zone owns item/object entities |
| Protocol | New **spawn-only** messages, mirroring M1's entity model |
| Rendering | Through SP1's `ZoneRenderer` + `SpriteCatalog` |

## Section 1 — Item catalog (shared module)

A new `shared.item` package, data-only, usable by server and client.

- **`ItemCategory`** — `RESOURCE`, `TOOL`, `FURNITURE`.
- **`ItemType`** — a catalog entry: stable integer `id`, `name`, `category`,
  `stackable:Bool`, and a sprite key (resolved by `SpriteCatalog` on the
  client). Defined as an `enum abstract`/registry so a numeric id crosses the
  wire and later sub-projects extend it.
- The **full legacy set**, as data:
  - **Resources (21):** wood, stone, flower, acorn, dirt, sand, cactus,
    seeds, wheat, bread, apple, coal, iron ore, gold ore, iron ingot,
    gold ingot, slime, glass, cloth, cloud, gem. (`stackable = true`.)
  - **Tools (25):** the 5 `ToolType`s — shovel, hoe, sword, pickaxe, axe — in
    5 material tiers — wood, rock, iron, gold, gem. (`stackable = false`.)
  - **Furniture (6):** workbench, furnace, oven, anvil, chest, lantern. These
    catalog entries are the *item* form; SP2 does not make them carryable —
    they exist as data so SP3 (carry/place) and SP5 (craft) need no catalog
    change.
- Behavior fields the legacy types carry (tool damage, food healing,
  plantable target tiles) are **omitted** — they belong to the sub-projects
  that consume them (SP4/SP5). The catalog is pure identity + render data.

`shared.item` has zero dependency on `engine` or `game`.

## Section 2 — World entities & placement (zone)

The zone gains two server-owned entity collections alongside its player
`Character`s:

- **`GroundItem`** — `{ id, itemType, count, tileX, tileY }`. Non-blocking.
- **`WorldObject`** — `{ id, objectType, tileX, tileY }` where `objectType`
  is a furniture `ItemType`. Blocking.

`ZoneSimulator` owns both, exposes them for spawn-broadcast and collision, and
its movement step is extended: a tile is walkable only if `map.isWalkable`
**and** unoccupied by a player **and** unoccupied by a `WorldObject`. Ground
items never block.

**Placement** is deterministic and server-side — no TMX/worldgen change:

- **World objects** are placed at fixed, hand-chosen tiles forming a small
  furnished "starter camp" a few tiles off the default spawn — a deliberate,
  inspectable arrangement (one of each furniture type).
- **Ground items** are scattered by a seeded RNG (the worldgen tree-scatter
  style) across walkable terrain near spawn, drawing item types from the
  catalog — enough to verify rendering of several item categories.

Placement runs once when the zone boots, after the map loads. It is data the
zone holds in memory; nothing is persisted (SP2 has no pickup, so item state
never changes).

## Section 3 — Protocol

New messages, following the M1 `MsgEntitySpawn` pattern (`shared.proto`,
registered in `MsgType`):

- **`MsgGroundItemSpawn`** — `{ worldItemId, itemTypeId, count, tileX, tileY }`
- **`MsgWorldObjectSpawn`** — `{ objectId, objectTypeId, tileX, tileY }`

On zone entry, after `MsgEnterZoneAck` and the existing player
`MsgEntitySpawn` burst, the zone sends one spawn message per ground item and
per world object. SP2 adds **no** move or despawn messages — items and objects
are static. Despawn arrives in SP3 with pickup; object lifecycle in SP4.

This is additive: no existing message changes, server authority is unchanged
(the zone still owns all world state).

## Section 4 — Client rendering

- **`SpriteCatalog`** gains a sprite registration for every `ItemType` —
  resource and tool cells from the legacy item sheet, furniture from the
  furniture sheet — coordinates cross-referenced from the legacy
  `game.SpriteNames`, exactly as SP1 did for terrain.
- **`ZoneRenderer`** gains two passes, drawn after terrain and before/with the
  entity pass: ground items (flat, one sprite per tile), then world objects.
  Z-order: terrain → ground items → world objects → player entities.
- The client holds the ground-item and world-object lists, populated from the
  spawn messages, addressed in `client.Main`'s zone dispatcher next to the
  existing entity handlers.
- **Missing-sprite safety:** an item/object whose sprite is unregistered draws
  the magenta placeholder (the SP1 `drawMissing` path), never crashes.

## Section 5 — Testing & error handling

**Automated:**

- `shared-test`: the catalog has the expected member count per category;
  every `ItemType` id is unique and stable; furniture entries are category
  `FURNITURE`.
- `client-test`: `SpriteCatalog` has a registered sprite for every `ItemType`
  (completeness check — pure data, no GPU), extending the SP1 test.
- `server-test`: world-object tiles block movement (a `MoveIntent` into an
  object tile is rejected); ground-item tiles do not block; placement is
  deterministic (same seed → same layout); spawn messages round-trip through
  serialize/deserialize.
- Regression: the existing 119 `shared-test`, 14 `client-test`, and 77
  `server-test` assertions still pass — SP2 is additive.

**Manual eyes-on guide** (`README-SUBPROJECT2.md`, M1/SP1 style): logging in,
the world shows scattered item sprites on the ground and a cluster of
furniture; the player cannot walk through furniture but walks freely over
ground items.

**Error handling:** an unknown item/object type id on the wire renders the
magenta placeholder rather than crashing; a failed sprite-sheet load fails
fast naming the missing file (the SP1 contract).

## Risks

- **Sprite coordinates.** Item and furniture cells in the legacy
  `SpriteNames` are authoritative, but furniture is composed from four 8×8
  cells (16×16) in the original; SP2 must pick a representative single cell or
  render the 2×2 — a manual art-matching step, as flagged in SP1.
- **Catalog extensibility.** `ItemType` must carry stable wire ids and stay
  open for SP3–SP5 to attach behavior without renumbering. Mitigated by
  keeping the catalog pure data with explicit ids.
- **Collision composition.** World-object blocking must compose cleanly with
  the existing terrain and player-occupancy checks in `ZoneSimulator.tick()` —
  one unified walkability predicate, covered by tests.

## Sub-project boundary

SP2 is complete when the MMO world is populated with rendered ground items
(full catalog available, a representative scatter placed) and rendered,
collidable furniture, all server-authoritative, with the automated suites
green and the eyes-on guide written. Picking items up and the inventory that
holds them is SP3.
