# Unified Entity Model (Mobiles + Items) — Design

**Date:** 2026-05-19
**Status:** Approved (design); pending implementation plan

## Context

The UO-patterns arc, sub-project 2 of 3:

1. Tick scheduler (timers) — *done; merged in `ad1d2c2`*
2. **Unified `Mobile` / `Item` entity model + serials** ← *this spec*
3. Sector grid (spatial index)

Today the zone has three separate "addressable thing" classes, each with its
own id space and wire family:

| Class | Id source | Container | Wire |
|---|---|---|---|
| `Character` | DB auto-increment (`characters.id`) | `entities:Map<Int, Character>` | `MsgEntitySpawn` / `MsgEntityMove` / `MsgEntityDespawn` |
| `GroundItem` | `nextGroundItemId` (zone-local, in-memory) | `groundItems:Array<GroundItem>` | `MsgGroundItemSpawn` / `MsgGroundItemDespawn` |
| `WorldObject` | `nextObjectId` (zone-local, in-memory) | `worldObjects:Array<WorldObject>` | `MsgWorldObjectSpawn` |
| `ItemStack` (carried) | *none — anonymous slot* | `Inventory.slots:Array<ItemStack>` | `MsgInventory` (the whole inventory) |

This is workable today but breaks down for what M3+ wants:

- **Monsters/NPCs** need an addressable thing that behaves like a `Character`
  but has no `conn`. Forking `Character` for AI is the wrong shape — we want
  one `Mobile` class with a nullable connection.
- **Persistent furniture and dropped items** need DB identity. The current
  zone-local counters reset on restart, so dropped ground items vanish and
  placed furniture can only be rebuilt by re-running the populator.
- **Item individuality** (a specific iron sword vs. another) and future
  containers (chests, equipment layers) need each item to have its own id,
  not just an anonymous slot in someone's inventory.

UO's solution is the *Serial* — every Mobile and every Item has a globally
unique id, and Items carry a `Parent` pointer (world / mobile / container) so
"this sword belongs to that NPC" is one field. We adopt that shape.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Scope of unification | Full: Mobile + Item replace Character / GroundItem / WorldObject / ItemStack |
| Serial source | Persistent, DB-backed, globally unique |
| Serial range strategy | UO-style bit range — mobiles `0x00000001..0x3FFFFFFF`, items `0x40000000..0x7FFFFFFF` |
| DB layout | Two tables: `mobiles` + `items` |
| Ground-item persistence | Yes — every ground item is persisted |
| Wire collapse | Full — one `MsgEntity*` family covers both kinds |
| Spawn payload shape | Single message with all fields present; per-kind fields zero/empty when unused |
| Pickup wire | `MsgEntityMove` with a re-parent (world → mobile), not despawn-plus-inventory |
| Sub-project split | One spec, one arc-2 sub-project |

## Scope

**In scope:** `Mobile` and `Item` classes; the bit-range Serial allocator;
DB schema (`mobiles`, `items`) and a migration from `characters` +
`character_items`; replacing `Character` / `GroundItem` / `WorldObject` /
`ItemStack` in `server.zone`; rewriting `Inventory` as a slot-ordered view
over a mobile's items; collapsing the wire to `MsgEntity*` with re-parent
moves; updating `WorldPopulator` to only seed on first boot.

**Out of scope:** NPC behavior and AI (M3); equipment layers and containers
beyond inventory; multi-zone serial spaces (the bit range is global *within*
a server, but we still assume one zone); item attributes/durability/charges
(future); the sector grid (arc 3/3); converting `nextMoveTick` or `growTiles`
to entity-driven schedulers (decided out of scope in the tick-scheduler spec
and unchanged here).

## Section 1 — Serial space

A `Serial` is a plain `Int`. The top bit of bit-30 (`0x40000000`) discriminates:

- **Mobile range:** `0x00000001..0x3FFFFFFF` (1 … 1 073 741 823).
- **Item range:**   `0x40000000..0x7FFFFFFF` (1 073 741 824 … 2 147 483 647).

This matches UO's classic layout and means *the id alone tells you the kind* —
no separate discriminator field is needed on the wire or in code paths that
hold a bare `Int`.

**Allocation.** A new module `server.zone.Serials` exposes:

- `Serials.isMobile(id:Int):Bool` — `(id & 0x40000000) == 0 && id != 0`.
- `Serials.isItem(id:Int):Bool`   — `(id & 0x40000000) != 0`.
- `Serials.nextMobile():Int` — allocates and persists.
- `Serials.nextItem():Int`   — allocates and persists.

Allocation is *not* derived from auto-increment alone, because the mobile
range and item range share the underlying `BIGINT` but must stay disjoint.
The simplest persistent counter is a single-row `serial_counters` table with
two columns (`mobile_next`, `item_next`), updated transactionally on each
allocation. On boot the in-memory `Serials` reads both values once and caches
them, then writes back on each `next*` call (or batches; see Risks).

`characters.id` already uses small auto-increment ints, so any existing
character row has a serial that already lives inside the mobile range. The
migration seeds `mobile_next` to `MAX(characters.id) + 1`. The first item
serial is `0x40000000` exactly.

## Section 2 — `Mobile` and `Item`

Two new files in `server.zone`, replacing `Character.hx`, `GroundItem.hx`,
`WorldObject.hx`, and the shared `ItemStack.hx`:

**`server/src/server/zone/Mobile.hx`** — what used to be `Character`:

```haxe
class Mobile {
  public var serial:Int;                     // mobile range
  public var name:String;
  public var conn:Null<ClientConnection>;    // null for NPCs / offline
  public var tileX:Int;
  public var tileY:Int;
  public var nextMoveTick:Int = 0;
  public var pendingDir:Int = -1;
  public var inventory:Inventory;            // ordered view; see §6
  // (combat fields land in M3.)
}
```

**`server/src/server/zone/Item.hx`** — what used to be `GroundItem`,
`WorldObject`, and the slot-anonymous `ItemStack`:

```haxe
class Item {
  public var serial:Int;                     // item range
  public var itemType:ItemType;
  public var count:Int;                      // 1 for non-stackable / placed
  public var parent:Null<Mobile>;            // null = in the world
  public var tileX:Int;                      // world position (parent == null)
  public var tileY:Int;
  public var slot:Int;                       // ordering when parent != null
}
```

An Item is in exactly one of two states:

- **In the world** — `parent == null`; `tileX/tileY` are authoritative;
  `slot` is ignored.
- **Carried by a mobile** — `parent != null`; `slot` is its position in that
  mobile's inventory; `tileX/tileY` are stale (we don't clear them so a
  re-drop can re-use them, but reads must check `parent` first).

**Blocking is a function of `itemType`, not a field.** Today only furniture
(category `FURNITURE`) blocks; resources and tools on the ground do not.
`canStep` consults `itemType.category() == FURNITURE` rather than a stored
flag. No `WorldObject` / `GroundItem` distinction survives.

## Section 3 — DB schema

Two new tables (migration `0005_entities.sql`):

```sql
CREATE TABLE mobiles (
    serial      BIGINT PRIMARY KEY,         -- mobile range
    account_id  BIGINT NULL,                -- NULL for NPCs
    name        VARCHAR(64) NOT NULL,
    zone_id     INT NOT NULL DEFAULT 1,
    tile_x      INT NOT NULL,
    tile_y      INT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login  TIMESTAMP NULL,
    UNIQUE KEY uq_mobiles_account (account_id),
    UNIQUE KEY uq_mobiles_name    (name),
    CONSTRAINT fk_mobiles_account
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

CREATE TABLE items (
    serial         BIGINT PRIMARY KEY,      -- item range
    item_type_id   INT NOT NULL,
    count          INT NOT NULL,
    parent_serial  BIGINT NULL,             -- NULL = in the world
    zone_id        INT NULL,                -- NOT NULL when parent IS NULL
    tile_x         INT NULL,                -- NOT NULL when parent IS NULL
    tile_y         INT NULL,                -- NOT NULL when parent IS NULL
    slot           INT NULL,                -- NOT NULL when parent IS NOT NULL
    INDEX idx_items_parent (parent_serial),
    INDEX idx_items_world  (zone_id, tile_x, tile_y),
    CONSTRAINT fk_items_parent
      FOREIGN KEY (parent_serial) REFERENCES mobiles(serial) ON DELETE CASCADE
);

CREATE TABLE serial_counters (
    id           TINYINT PRIMARY KEY,       -- always 1
    mobile_next  BIGINT NOT NULL,
    item_next    BIGINT NOT NULL
);
```

Foreign-keying `items.parent_serial` to `mobiles.serial` is correct *for now*
(carried items only); when containers (chests) arrive in M-later, the FK
relaxes — an item can also parent to another item. The spec accepts the
narrower constraint today and notes it as future relaxation.

**Migration of existing data:**

1. `INSERT INTO mobiles (serial, account_id, name, zone_id, tile_x, tile_y,
   created_at, last_login) SELECT id, account_id, name, zone_id, tile_x,
   tile_y, created_at, last_login FROM characters;`
2. For each row in `character_items`, allocate a fresh item serial (starting
   from `0x40000000`) and `INSERT INTO items (serial, item_type_id, count,
   parent_serial, slot)` with `parent_serial = character_id` and the existing
   `slot`.
3. `INSERT INTO serial_counters (id, mobile_next, item_next) VALUES (1,
   MAX(mobiles.serial)+1, MAX(items.serial)+1);` — computed at migration
   time so the next allocation is safe.
4. `DROP TABLE character_items; DROP TABLE characters;`

A fresh DB starts both counters at the bottom of each range.

## Section 4 — `ZoneSimulator` integration

The simulator collapses to a single entity map plus a world-position index
that survives until the sector grid (arc 3/3) replaces it:

- `mobiles:Map<Int, Mobile>` — keyed by serial (replaces `entities`).
- `items:Map<Int, Item>` — keyed by serial (replaces `groundItems` and
  `worldObjects`).
- `entityAt(x,y):Null<Mobile>`, `itemAt(x,y):Null<Item>`, `objectAt(x,y):Bool`
  — same names externally; internally they iterate the unified maps.

The `freshGroundItemId()` / `freshObjectId()` methods are deleted. Callers
(`WorldPopulator`, `Crafting`, anywhere that creates an item) call
`Serials.nextItem()` and construct an `Item` directly.

**Boot:**

- On first boot of a fresh DB (or a fresh zone), `WorldPopulator.populate`
  runs as today — but every `new Item(...)` it creates is inserted into
  `items` immediately.
- On a re-boot with an existing DB, the simulator loads all `items` and
  `mobiles` for `zone_id = 1` from the DB and the populator is *skipped*.
  Detection: `if (itemDal.countForZone(1) == 0) populate()`. This is
  intentional — persistent ground items mean re-running the populator would
  duplicate them.

**Flush:**

- `flushPositions` becomes `flushEntities` and writes back the dirty mobile
  positions and inventory shapes. Persistent items already live in the DB;
  their `tile_x/tile_y/parent_serial/slot` updates happen at mutation time
  (drop, pickup, place), not on a 50-tick cadence — items don't drift, so
  there is nothing to "save periodically" for them.

## Section 5 — Wire protocol

The `MsgGroundItem*` and `MsgWorldObjectSpawn` families are removed.
`MsgEntity*` carries everything:

**`MsgEntitySpawn`** gains a fixed-shape body that fits both kinds. Fields
unused for a given kind are zero or empty:

```haxe
class MsgEntitySpawn implements Serializable {
  public var serial:Int = 0;             // top bit discriminates kind
  // Mobile fields (used when serial is in mobile range)
  public var name:String = "";
  // Item fields (used when serial is in item range)
  public var itemTypeId:Int = 0;
  public var count:Int = 0;
  // Shared position (used when in the world)
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  // Parent (used when in a container/inventory)
  public var parentSerial:Int = 0;       // 0 = in the world
  public var slot:Int = 0;
  public function new() {}
}
```

The client reads `serial`, derives kind via `Serials.isMobile`, and renders
either a player sprite (mobile) or an item sprite (item). Items with
`parentSerial != 0` are inventory contents and never enter the world-render
list.

**`MsgEntityMove`** gains a re-parent variant. Existing tile-step fields
stay; new fields encode pickup/drop:

```haxe
class MsgEntityMove implements Serializable {
  public var serial:Int = 0;
  // Tile step (the only form used today)
  public var fromX:Int = 0;
  public var fromY:Int = 0;
  public var toX:Int = 0;
  public var toY:Int = 0;
  // Re-parent (used when picking up / dropping / placing)
  public var newParentSerial:Int = 0;    // 0 = becomes world-placed at toX/toY
  public var newSlot:Int = 0;
  public function new() {}
}
```

A tile-step move sets `newParentSerial = 0` and leaves `from*/to*` filled —
behaviorally identical to today's mobile moves. A pickup sets
`newParentSerial = mobileSerial`, `newSlot = slot`, and the client moves the
item's sprite from world to inventory UI. A drop is the reverse.

**`MsgEntityDespawn`** is unchanged in shape; it now also fires when an item
is destroyed (used up by crafting, stack merged into another, etc.).

**`MsgInventory`** stays — it's still the convenient bulk "here is your
inventory" shipped on zone entry. Its body changes to a list of
`{serial, itemTypeId, count}` rows so the client knows each slot's serial.

**Removed wire types:** `MsgGroundItemSpawn`, `MsgGroundItemDespawn`,
`MsgWorldObjectSpawn`. Their `MsgType` ids (`GROUND_ITEM_SPAWN = 30`,
`WORLD_OBJECT_SPAWN = 31`, `GROUND_ITEM_DESPAWN = 33`) are removed too — no
backwards-compat aliases.

## Section 6 — Inventory

`Inventory` keeps its slot-ordered API (`add`, `removeCount`, `activeItem`,
`activeSlot`) but its storage is now `Array<Item>` instead of
`Array<ItemStack>`:

- `add(itemType, count)` for a **stackable** type finds the slot whose `Item`
  has the same `itemType` and increments its `count` (and persists). No new
  Item is created — stack merging happens at the existing record.
- `add(itemType, count)` for a **non-stackable** type allocates a new item
  serial via `Serials.nextItem()`, creates the `Item` with `parent = mobile`
  and `slot = slots.length`, and appends.
- `add(existingItem:Item)` (the pickup overload) re-parents `existingItem` to
  this mobile rather than creating a new one — the serial survives. If the
  same itemType is already in a slot and is stackable, merge counts and
  destroy `existingItem` instead.
- `removeCount(itemType, count)` walks slots; when an Item's `count` drops to
  zero, it is destroyed (DB delete + `MsgEntityDespawn`).

The shared `ItemStack.hx` file is deleted; client-side rendering uses a
plain `{itemTypeId, count}` typedef where the value matters.

## Section 7 — Pickup as re-parent

Today, walking onto a ground item does: `inventory.add(itemType, count)` +
`groundItems.remove(gi)` + `MsgGroundItemDespawn` + `MsgInventory`. After
this spec:

1. The simulator finds `itemAt(nx, ny)` returns an Item `gi`.
2. `mobile.inventory.add(gi)` — re-parents (or merges and destroys) the
   existing Item. Serial survives in the merge case via the kept stack; in
   the re-parent case via `gi` itself.
3. The simulator emits **one** `MsgEntityMove` with `serial = gi.serial`,
   `newParentSerial = mobile.serial`, `newSlot = gi.slot`. Same-zone
   observers update their view; the moving mobile's client knows to drop the
   sprite from the world layer and add it to inventory UI.
4. If a stack merge destroyed the picked-up Item, the simulator emits a
   `MsgEntityDespawn` for it as well — this is the only path that despawns
   an item from a pickup.

`pickupsThisTick`, `MsgGroundItemDespawn`, and the parallel `MsgInventory`
broadcast on pickup all go away. The client updates inventory by listening
to `MsgEntityMove` re-parents directed at its own mobile.

## Section 8 — Edge cases

- **Same-serial collisions across runs.** Serials never reset; the counters
  table is the source of truth. A test asserts that two consecutive allocs
  on a fresh DB return different values and that a restart preserves them.
- **A pickup of a stackable that merges.** Both the surviving stack
  (`MsgEntityMove` with new `count`? — no: `count` isn't on `MsgEntityMove`)
  and the destroyed Item (`MsgEntityDespawn`) need to update the client.
  The convention: stack merges emit `MsgEntityDespawn` for the consumed
  Item; the surviving stack's new count rides on a subsequent
  `MsgEntitySpawn` *replay* shape only on zone-entry, not on every pickup.
  Inline merges send a small dedicated update — TBD by the plan; the
  simplest is a `MsgInventory` refresh for the recipient mobile only.
- **Furniture placement.** Today `PlaceFurniture` allocates a `WorldObject`.
  After the spec, it allocates an `Item` with `parent = null`,
  `tileX/tileY = target`, and `itemType` of the placed furniture. Blocking
  is automatic via the category check.
- **WorldPopulator on re-boot.** A populated zone must not re-populate;
  otherwise restart duplicates the camp and scatter. The
  `itemDal.countForZone == 0` check covers this; the test seeds the items
  table and confirms `WorldPopulator.populate` is not called.
- **Migration on a DB with an empty `character_items`.** The migration must
  initialize `serial_counters.item_next` to `0x40000000` even when no item
  rows exist. A test exercises both the empty-inventory and populated cases.
- **Re-parent move into a slot that already exists.** When `add(existingItem)`
  finds an existing stackable slot of the same type, the *kept* item is the
  one already in the inventory (its serial is stable); the incoming one is
  destroyed. This matters for any future "inspect by serial" UI — players
  see consistent stack identities across pickups.

## Section 9 — Testing

**Unit:**

- `TestSerials` — bit-range classification (`isMobile` / `isItem`),
  monotonic allocation, the counters round-trip through a fake DAL.
- `TestItem` — parent toggling (`parent = null` ↔ a mobile), slot ordering,
  blocking derived from category.
- `TestInventory` — same suite as today (stackable merge, removeCount,
  activeItem) but on the new `Array<Item>` storage; plus a re-parent test
  (`add(existingItem)` merges into an existing stack and destroys the
  argument).

**Integration:**

- `TestZoneLifecycle` — already covers walk → logout → position persisted;
  now also asserts inventory item serials survive logout/login.
- `TestZonePickup` — a new test that walks a mobile onto a ground item and
  asserts: (a) a single `MsgEntityMove` is emitted, (b) the item's row in
  `items` has its `parent_serial` updated, (c) on simulated restart the
  item is in the mobile's inventory, not on the ground.
- `TestZoneBoot` — a fresh-DB boot runs `WorldPopulator` and inserts rows;
  a second boot loads them and does *not* re-populate.

**Regression:** the full shared / client / server / integration suite stays
green. The headless bots smoke-test (`tools/zone-bots`) is the catch-net
for the wire collapse landing wrong.

## Risks

- **Migration is one-way.** Dropping `characters` and `character_items` is
  irreversible; a botched migration on a production-ish DB loses everyone's
  inventory. The plan must ship a rollback script that re-creates the old
  tables from `mobiles` + `items` so we can recover during arc-2 review.
- **Wire breakage is total.** Removing `MsgGroundItem*` / `MsgWorldObject*`
  means a pre-arc-2 client cannot connect to a post-arc-2 server. We accept
  this (we have no installed clients to support), but the bots and the dev
  flow need to be cut over atomically.
- **Serial counter contention.** A single-row `serial_counters` table is the
  bottleneck for every entity creation. At haxecraft's current scale this is
  fine, but the plan should batch (`Serials` pre-allocates a chunk of 100
  and writes back on chunk exhaustion) to avoid one DB write per spawned
  item during the world-populate burst.
- **Item-as-record is a behavior change beyond refactor.** Stack merges,
  inventory ordering, and pickup semantics all visibly change shape on the
  wire. The integration tests above are the only thing standing between us
  and a "looks fine, breaks in production" outcome. The plan must wire them
  before any deletion of the old classes.

## Sub-project boundary

Complete when: `Mobile` and `Item` replace `Character` / `GroundItem` /
`WorldObject` / `ItemStack`; `mobiles` and `items` are the canonical DB
tables; `Serials` allocates from the persistent counters; pickup is one
`MsgEntityMove` re-parent; `MsgGroundItem*` and `MsgWorldObjectSpawn` are
deleted; `WorldPopulator` no-ops on a populated zone; the full suite is
green and the headless bots smoke-test passes against the collapsed wire.

The sector grid (arc 3/3) follows next, replacing the unified-but-still-
linear `entityAt` / `itemAt` scans with an O(1) tile→entity lookup.
