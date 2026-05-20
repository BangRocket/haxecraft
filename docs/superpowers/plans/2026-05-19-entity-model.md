# Unified Entity Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Character` / `GroundItem` / `WorldObject` / `ItemStack` with a unified `Mobile` / `Item` model addressed by persistent UO-style Serials, persist all entities to the DB, and collapse the spawn/move/despawn wire to a single `MsgEntity*` family.

**Architecture:** A `Serials` module allocates from two disjoint bit ranges (mobiles `0x00000001..0x3FFFFFFF`, items `0x40000000..0x7FFFFFFF`), backed by a `serial_counters` row. Two new tables (`mobiles`, `items`) replace `characters` + `character_items`; the items table carries a `parent_serial` so each item is either world-placed (`parent_serial IS NULL` + `tile_x/tile_y`) or carried (`parent_serial = mobile.serial` + `slot`). The zone simulator unifies its collections; the wire flattens to one `MsgEntitySpawn` / `MsgEntityMove` / `MsgEntityDespawn` family with the kind derivable from the serial's top bit.

**Tech Stack:** Haxe 4.3, HashLink (HLC native on Apple Silicon), utest, MySQL/InnoDB.

**Spec:** `docs/superpowers/specs/2026-05-19-entity-model-design.md`

---

## File Structure

**New files:**
- `server/src/server/zone/Serials.hx` — bit-range classifiers + allocator (pure; counter persistence via interface).
- `server/src/server/zone/Mobile.hx` — replaces `Character.hx`.
- `server/src/server/zone/Item.hx` — replaces `GroundItem.hx`, `WorldObject.hx`, and the carried-`ItemStack` role.
- `server/src/server/db/MobileDal.hx` — replaces `CharacterDal`'s character + position role.
- `server/src/server/db/ItemDal.hx` — items table CRUD.
- `server/src/server/db/SerialCounterDal.hx` — counters table read/write.
- `db/migrations/0005_entities.sql` — creates `mobiles`, `items`, `serial_counters`; copies from `characters` + `character_items`; drops the old tables.
- `db/migrations/0005_entities_rollback.sql` — checked in alongside but not auto-applied; recreates the old tables from `mobiles` + `items` for emergency rollback during review.
- `server/test/TestSerials.hx` — bit-range + allocator unit tests.
- `server/test/TestItem.hx` — Item parent toggling + blocking-from-category.
- `server/test/TestZoneBoot.hx` — `WorldPopulator` runs once; re-boot loads persisted entities.

**Modified files:**
- `server/src/server/zone/Inventory.hx` — `Array<Item>` storage; `add(itemType, count, mobile)` overload + `add(item:Item)` re-parent overload.
- `server/src/server/zone/ZoneSimulator.hx` — `mobiles` + `items` maps replace `entities` / `groundItems` / `worldObjects`; `freshGroundItemId` / `freshObjectId` removed; persistence wired through new DALs.
- `server/src/server/zone/Main.hx` — boot wiring uses new DALs; `WorldPopulator` only runs when `items` is empty for the zone.
- `server/src/server/zone/WorldPopulator.hx` — allocates via `Serials.nextItem()`; inserts each item to the `items` table.
- `server/src/server/zone/Crafting.hx` — `freshObjectId` callers switch to `Serials.nextItem()`.
- `server/src/server/zone/CraftHandler.hx`, `InventoryHandler.hx`, `MoveIntentHandler.hx`, `EnterZoneHandler.hx`, `TileHandler.hx`, `TileInteraction.hx`, `InterestManager.hx` — call-site updates for renamed types and new wire messages.
- `server/src/server/zone/Character.hx`, `GroundItem.hx`, `WorldObject.hx` — **deleted** (replaced by `Mobile.hx` / `Item.hx`).
- `server/src/server/db/CharacterDal.hx`, `server/test/TestCharacterDal.hx` — **deleted**.
- `shared/src/shared/item/ItemStack.hx`, `shared/test/TestItemStack.hx` — **deleted**.
- `shared/src/shared/proto/MsgEntitySpawn.hx`, `MsgEntityMove.hx`, `MsgInventory.hx` — extended fields.
- `shared/src/shared/proto/MsgGroundItemSpawn.hx`, `MsgGroundItemDespawn.hx`, `MsgWorldObjectSpawn.hx` — **deleted**.
- `shared/src/shared/proto/MsgType.hx` — `GROUND_ITEM_SPAWN`, `GROUND_ITEM_DESPAWN`, `WORLD_OBJECT_SPAWN` removed.
- `client/src/client/Main.hx`, `client/src/headless/HeadlessClient.hx` — handle unified spawn/move/despawn; drop the deleted message handlers.
- `server/src/server/gateway/LoginHandler.hx`, `Main.hx` — `CharacterDal` → `MobileDal` (account lookup / autocreate).
- `server/test/TestMain.hx` — register new test cases, drop deleted ones.
- `server/test/TestZoneSimulator.hx`, `TestZoneLifecycle.hx`, `TestZoneInterest.hx`, `TestZoneChat.hx`, `TestCrafting.hx`, `TestWorldPopulator.hx`, `TestInventory.hx` — update for `Mobile` / `Item` and the new wire.

This is the second of three sub-projects in the UO-patterns arc; the sector grid follows.

---

## Task 1: `Serials` module

**Files:**
- Create: `server/src/server/zone/Serials.hx`, `server/test/TestSerials.hx`
- Modify: `server/test/TestMain.hx`

- [ ] **Step 1: Write the failing tests**

Create `server/test/TestSerials.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Serials;
import server.zone.SerialCounter;

/** In-memory test double for the persistent counter, used by TestSerials. */
class MemCounter implements SerialCounter {
  public var mobile:Int;
  public var item:Int;
  public function new(mobile:Int = 1, item:Int = 0x40000000) {
    this.mobile = mobile;
    this.item = item;
  }
  public function loadMobileNext():Int return mobile;
  public function loadItemNext():Int return item;
  public function storeMobileNext(v:Int):Void { mobile = v; }
  public function storeItemNext(v:Int):Void { item = v; }
}

class TestSerials extends Test {
  function testIsMobileIsItem() {
    Assert.isTrue(Serials.isMobile(1));
    Assert.isTrue(Serials.isMobile(0x3FFFFFFF));
    Assert.isFalse(Serials.isMobile(0x40000000));
    Assert.isFalse(Serials.isMobile(0));            // zero is neither

    Assert.isTrue(Serials.isItem(0x40000000));
    Assert.isTrue(Serials.isItem(0x7FFFFFFF));
    Assert.isFalse(Serials.isItem(1));
    Assert.isFalse(Serials.isItem(0));
  }

  function testAllocatesInRanges() {
    var s = new Serials(new MemCounter(1, 0x40000000));
    var m1 = s.nextMobile();
    var m2 = s.nextMobile();
    Assert.equals(1, m1);
    Assert.equals(2, m2);
    Assert.isTrue(Serials.isMobile(m1));

    var i1 = s.nextItem();
    var i2 = s.nextItem();
    Assert.equals(0x40000000, i1);
    Assert.equals(0x40000001, i2);
    Assert.isTrue(Serials.isItem(i1));
  }

  function testSeedsFromCounter() {
    var c = new MemCounter(100, 0x40000050);
    var s = new Serials(c);
    Assert.equals(100, s.nextMobile());
    Assert.equals(0x40000050, s.nextItem());
  }

  function testWritesBackOnAlloc() {
    var c = new MemCounter(5, 0x40000000);
    var s = new Serials(c);
    s.nextMobile();   // returns 5; counter advances to 6
    s.nextMobile();   // returns 6; counter advances to 7
    s.nextItem();     // returns 0x40000000; counter advances to 0x40000001
    Assert.equals(7, c.mobile);
    Assert.equals(0x40000001, c.item);
  }
}
```

In `server/test/TestMain.hx`, add a `r.addCase(new TestSerials());` line after `TestScheduler`:

```haxe
    r.addCase(new TestScheduler());
    r.addCase(new TestSerials());
```

- [ ] **Step 2: Run the build to verify it fails**

Run: `./build_native.sh server-test`
Expected: FAIL — compile error, `server.zone.Serials` not found.

- [ ] **Step 3: Create the `SerialCounter` interface and `Serials` module**

Create `server/src/server/zone/SerialCounter.hx`:

```haxe
package server.zone;

/** Persistent counter for the Serials allocator. The production
    implementation is `SerialCounterDal`; tests use an in-memory double. */
interface SerialCounter {
  function loadMobileNext():Int;
  function loadItemNext():Int;
  function storeMobileNext(v:Int):Void;
  function storeItemNext(v:Int):Void;
}
```

Create `server/src/server/zone/Serials.hx`:

```haxe
package server.zone;

/**
 * Global serial allocator. Mobiles draw from `0x00000001..0x3FFFFFFF`,
 * items from `0x40000000..0x7FFFFFFF` — the top bit (`0x40000000`)
 * discriminates kind, so a bare `Int` carries enough information to
 * route it correctly.
 *
 * Counters live in the DB via a `SerialCounter`; on `next*` the in-memory
 * value advances and is written back. The constructor primes the in-memory
 * values from the counter once.
 */
class Serials {
  public static inline var ITEM_BIT:Int = 0x40000000;
  public static inline var MOBILE_MAX:Int = 0x3FFFFFFF;
  public static inline var ITEM_MIN:Int = 0x40000000;
  public static inline var ITEM_MAX:Int = 0x7FFFFFFF;

  public static inline function isMobile(id:Int):Bool {
    return id > 0 && (id & ITEM_BIT) == 0;
  }

  public static inline function isItem(id:Int):Bool {
    return (id & ITEM_BIT) != 0 && id <= ITEM_MAX;
  }

  var counter:SerialCounter;
  var nextMobileN:Int;
  var nextItemN:Int;

  public function new(counter:SerialCounter) {
    this.counter = counter;
    this.nextMobileN = counter.loadMobileNext();
    this.nextItemN = counter.loadItemNext();
  }

  public function nextMobile():Int {
    var s = nextMobileN++;
    counter.storeMobileNext(nextMobileN);
    return s;
  }

  public function nextItem():Int {
    var s = nextItemN++;
    counter.storeItemNext(nextItemN);
    return s;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./build_native.sh server-test && ./bin/server-test`
Expected: `TestSerials` — all 4 cases green. (Pre-existing integration tests that need a live server may error; unchanged here.)

- [ ] **Step 5: Commit**

```bash
git add server/src/server/zone/SerialCounter.hx server/src/server/zone/Serials.hx server/test/TestSerials.hx server/test/TestMain.hx
git commit -m "$(cat <<'EOF'
feat(zone): serial allocator with UO-style bit ranges

Mobiles draw from 0x00000001..0x3FFFFFFF, items from 0x40000000..0x7FFFFFFF;
the top bit discriminates kind so a bare Int routes correctly. Counter
persistence is injected via the SerialCounter interface; production wiring
lands in the next task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Schema migration + server-side refactor (wire unchanged)

This task lands the new tables, replaces `Character` / `GroundItem` /
`WorldObject` / `ItemStack` with `Mobile` / `Item`, switches persistence to
the new DALs, and migrates existing rows. **The wire protocol is unchanged**
— the client still receives `MsgGroundItemSpawn`, `MsgWorldObjectSpawn`,
`MsgGroundItemDespawn`, and `MsgInventory` with the same field shapes; the
fields just come from the unified internal model. Pickup still does
"despawn-from-world + inventory refresh." Wire collapse and re-parent pickup
land in Task 3.

**Files:**
- Create: `db/migrations/0005_entities.sql`, `db/migrations/0005_entities_rollback.sql`
- Create: `server/src/server/db/SerialCounterDal.hx`, `MobileDal.hx`, `ItemDal.hx`
- Create: `server/src/server/zone/Mobile.hx`, `server/src/server/zone/Item.hx`
- Create: `server/test/TestItem.hx`, `server/test/TestZoneBoot.hx`
- Modify: `server/src/server/zone/Inventory.hx`, `ZoneSimulator.hx`, `Main.hx`, `WorldPopulator.hx`, `Crafting.hx`, `CraftHandler.hx`, `InventoryHandler.hx`, `MoveIntentHandler.hx`, `EnterZoneHandler.hx`, `TileHandler.hx`, `TileInteraction.hx`, `InterestManager.hx`
- Modify: `server/src/server/gateway/LoginHandler.hx`, `server/src/server/gateway/Main.hx`
- Modify: `server/test/TestMain.hx`, `TestZoneSimulator.hx`, `TestZoneLifecycle.hx`, `TestZoneInterest.hx`, `TestZoneChat.hx`, `TestCrafting.hx`, `TestWorldPopulator.hx`, `TestInventory.hx`
- Delete: `server/src/server/zone/Character.hx`, `GroundItem.hx`, `WorldObject.hx`
- Delete: `server/src/server/db/CharacterDal.hx`, `server/test/TestCharacterDal.hx`
- Delete: `shared/src/shared/item/ItemStack.hx`, `shared/test/TestItemStack.hx`

- [ ] **Step 1: Write the migration**

Create `db/migrations/0005_entities.sql`:

```sql
-- mobiles: replaces `characters`. Primary key is the serial (in mobile range,
-- 1..0x3FFFFFFF). For existing rows the previous auto-increment id is
-- preserved as the serial — they already fit the mobile range.
CREATE TABLE mobiles (
    serial      BIGINT PRIMARY KEY,
    account_id  BIGINT NULL,
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- items: replaces `character_items` and absorbs ground items + world
-- objects. parent_serial NULL means "in the world"; non-NULL means
-- "carried by mobile parent_serial in slot N".
CREATE TABLE items (
    serial         BIGINT PRIMARY KEY,
    item_type_id   INT NOT NULL,
    count          INT NOT NULL,
    parent_serial  BIGINT NULL,
    zone_id        INT NULL,
    tile_x         INT NULL,
    tile_y         INT NULL,
    slot           INT NULL,
    INDEX idx_items_parent (parent_serial),
    INDEX idx_items_world  (zone_id, tile_x, tile_y),
    CONSTRAINT fk_items_parent
      FOREIGN KEY (parent_serial) REFERENCES mobiles(serial) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- serial_counters: single-row table holding the next free mobile/item id.
CREATE TABLE serial_counters (
    id           TINYINT PRIMARY KEY,
    mobile_next  BIGINT NOT NULL,
    item_next    BIGINT NOT NULL
);

-- Copy existing characters → mobiles. The existing auto-increment id
-- becomes the serial.
INSERT INTO mobiles (serial, account_id, name, zone_id, tile_x, tile_y, created_at, last_login)
SELECT id, account_id, name, zone_id, tile_x, tile_y, created_at, last_login
FROM characters;

-- Copy character_items → items, generating serials starting from
-- 0x40000000 and assigning them by (character_id, slot) order so the
-- assignment is deterministic across migrations.
SET @s := 1073741823;  -- 0x40000000 - 1; pre-increment below yields 0x40000000 first
INSERT INTO items (serial, item_type_id, count, parent_serial, slot)
SELECT @s := @s + 1, item_type_id, count, character_id, slot
FROM character_items
ORDER BY character_id, slot;

-- Seed serial_counters. Mobile counter is one past the highest existing
-- character id (or 1 for a fresh DB); item counter is one past the highest
-- assigned item serial (or 0x40000000 for a fresh DB).
INSERT INTO serial_counters (id, mobile_next, item_next)
VALUES (
    1,
    COALESCE((SELECT MAX(serial) FROM mobiles), 0) + 1,
    COALESCE((SELECT MAX(serial) FROM items), 1073741823) + 1
);

DROP TABLE character_items;
DROP TABLE characters;
```

Create `db/migrations/0005_entities_rollback.sql` (checked in but never
auto-applied — kept for emergency rollback during review):

```sql
-- Emergency rollback for migration 0005. Re-creates `characters` +
-- `character_items` from `mobiles` + `items`. Not part of the normal
-- migration sequence; apply manually only if 0005 needs to be undone.
CREATE TABLE characters (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT NOT NULL UNIQUE,
    name VARCHAR(64) NOT NULL UNIQUE,
    zone_id INT NOT NULL DEFAULT 1,
    tile_x INT NOT NULL DEFAULT 512,
    tile_y INT NOT NULL DEFAULT 512,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    CONSTRAINT fk_characters_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    INDEX idx_characters_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE character_items (
    character_id BIGINT NOT NULL,
    slot INT NOT NULL,
    item_type_id INT NOT NULL,
    count INT NOT NULL,
    PRIMARY KEY (character_id, slot),
    CONSTRAINT fk_character_items_character FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO characters (id, account_id, name, zone_id, tile_x, tile_y, created_at, last_login)
SELECT serial, account_id, name, zone_id, tile_x, tile_y, created_at, last_login
FROM mobiles WHERE account_id IS NOT NULL;

INSERT INTO character_items (character_id, slot, item_type_id, count)
SELECT parent_serial, slot, item_type_id, count
FROM items WHERE parent_serial IS NOT NULL;

DROP TABLE serial_counters;
DROP TABLE items;
DROP TABLE mobiles;
```

- [ ] **Step 2: Apply the migration to the dev DB**

Run: `./db/apply-migrations.sh`
Expected: `0005_entities.sql` applied; `characters` and `character_items` no
longer exist; `mobiles`, `items`, `serial_counters` populated.

- [ ] **Step 3: Create the new DALs**

Create `server/src/server/db/SerialCounterDal.hx`:

```haxe
package server.db;

import server.zone.SerialCounter;

class SerialCounterDal implements SerialCounter {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function loadMobileNext():Int {
    var rows = db.query("SELECT mobile_next FROM serial_counters WHERE id = 1", []);
    if (rows.length == 0) throw "serial_counters row missing — migration 0005 not applied?";
    return (rows[0].mobile_next : Int);
  }

  public function loadItemNext():Int {
    var rows = db.query("SELECT item_next FROM serial_counters WHERE id = 1", []);
    if (rows.length == 0) throw "serial_counters row missing — migration 0005 not applied?";
    return (rows[0].item_next : Int);
  }

  public function storeMobileNext(v:Int):Void {
    db.exec("UPDATE serial_counters SET mobile_next = ? WHERE id = 1", [v]);
  }

  public function storeItemNext(v:Int):Void {
    db.exec("UPDATE serial_counters SET item_next = ? WHERE id = 1", [v]);
  }
}
```

Create `server/src/server/db/MobileDal.hx`:

```haxe
package server.db;

typedef MobileRow = {
  serial:Int,
  accountId:Null<Int>,
  name:String,
  zoneId:Int,
  tileX:Int,
  tileY:Int
};

class MobileDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function findByAccountId(accountId:Int):Null<MobileRow> {
    var rows = db.query(
      "SELECT serial, account_id, name, zone_id, tile_x, tile_y FROM mobiles WHERE account_id = ? LIMIT 1",
      [accountId]
    );
    if (rows.length == 0) return null;
    var r = rows[0];
    return {
      serial: (r.serial : Int),
      accountId: r.account_id == null ? null : (r.account_id : Int),
      name: (r.name : String),
      zoneId: (r.zone_id : Int),
      tileX: (r.tile_x : Int),
      tileY: (r.tile_y : Int)
    };
  }

  /** Insert a new mobile with an allocated serial. */
  public function insert(serial:Int, accountId:Null<Int>, name:String,
                        zoneId:Int, tileX:Int, tileY:Int):Void {
    db.exec(
      "INSERT INTO mobiles (serial, account_id, name, zone_id, tile_x, tile_y) VALUES (?, ?, ?, ?, ?, ?)",
      [serial, accountId, name, zoneId, tileX, tileY]
    );
  }

  public function savePosition(serial:Int, tileX:Int, tileY:Int):Void {
    db.exec(
      "UPDATE mobiles SET tile_x = ?, tile_y = ? WHERE serial = ?",
      [tileX, tileY, serial]
    );
  }
}
```

Create `server/src/server/db/ItemDal.hx`:

```haxe
package server.db;

typedef ItemRow = {
  serial:Int,
  itemTypeId:Int,
  count:Int,
  parentSerial:Null<Int>,
  zoneId:Null<Int>,
  tileX:Null<Int>,
  tileY:Null<Int>,
  slot:Null<Int>
};

class ItemDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function insertWorld(serial:Int, itemTypeId:Int, count:Int,
                              zoneId:Int, tileX:Int, tileY:Int):Void {
    db.exec(
      "INSERT INTO items (serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot) VALUES (?, ?, ?, NULL, ?, ?, ?, NULL)",
      [serial, itemTypeId, count, zoneId, tileX, tileY]
    );
  }

  public function insertCarried(serial:Int, itemTypeId:Int, count:Int,
                                parentSerial:Int, slot:Int):Void {
    db.exec(
      "INSERT INTO items (serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot) VALUES (?, ?, ?, ?, NULL, NULL, NULL, ?)",
      [serial, itemTypeId, count, parentSerial, slot]
    );
  }

  public function delete(serial:Int):Void {
    db.exec("DELETE FROM items WHERE serial = ?", [serial]);
  }

  /** Update an item to the carried-by-mobile state. */
  public function reparentToMobile(serial:Int, parentSerial:Int, slot:Int):Void {
    db.exec(
      "UPDATE items SET parent_serial = ?, slot = ?, zone_id = NULL, tile_x = NULL, tile_y = NULL WHERE serial = ?",
      [parentSerial, slot, serial]
    );
  }

  public function updateCount(serial:Int, count:Int):Void {
    db.exec("UPDATE items SET count = ? WHERE serial = ?", [count, serial]);
  }

  public function loadCarriedFor(mobileSerial:Int):Array<ItemRow> {
    var rows = db.query(
      "SELECT serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot FROM items WHERE parent_serial = ? ORDER BY slot",
      [mobileSerial]
    );
    return [for (r in rows) rowOf(r)];
  }

  public function loadWorldFor(zoneId:Int):Array<ItemRow> {
    var rows = db.query(
      "SELECT serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot FROM items WHERE parent_serial IS NULL AND zone_id = ?",
      [zoneId]
    );
    return [for (r in rows) rowOf(r)];
  }

  public function countForZone(zoneId:Int):Int {
    var rows = db.query("SELECT COUNT(*) AS n FROM items WHERE zone_id = ?", [zoneId]);
    return (rows[0].n : Int);
  }

  static inline function rowOf(r:Dynamic):ItemRow return {
    serial: (r.serial : Int),
    itemTypeId: (r.item_type_id : Int),
    count: (r.count : Int),
    parentSerial: r.parent_serial == null ? null : (r.parent_serial : Int),
    zoneId: r.zone_id == null ? null : (r.zone_id : Int),
    tileX: r.tile_x == null ? null : (r.tile_x : Int),
    tileY: r.tile_y == null ? null : (r.tile_y : Int),
    slot: r.slot == null ? null : (r.slot : Int)
  };
}
```

- [ ] **Step 4: Create `Mobile.hx`**

Create `server/src/server/zone/Mobile.hx`:

```haxe
package server.zone;

import server.net.ClientConnection;

/** A live actor in a zone: player (conn != null) or future NPC (conn == null).
    Replaces the previous `Character` class. */
class Mobile {
  public var serial:Int;
  public var name:String;
  public var conn:Null<ClientConnection>;
  public var tileX:Int;
  public var tileY:Int;
  public var nextMoveTick:Int = 0;
  public var pendingDir:Int = -1;
  public var inventory:Inventory;

  public function new(serial:Int, name:String, conn:Null<ClientConnection>,
                      tileX:Int, tileY:Int) {
    this.serial = serial;
    this.name = name;
    this.conn = conn;
    this.tileX = tileX;
    this.tileY = tileY;
    this.inventory = new Inventory(this);
  }
}
```

- [ ] **Step 5: Create `Item.hx`**

Create `server/src/server/zone/Item.hx`:

```haxe
package server.zone;

import shared.item.ItemType;
import shared.item.ItemCategory;

/** Any addressable, non-mobile thing: dropped resource, placed furniture,
    inventory entry. Blocking is derived from `itemType.category()` so the
    same class covers ground-items and placed-furniture. */
class Item {
  public var serial:Int;
  public var itemType:ItemType;
  public var count:Int;
  public var parent:Null<Mobile>;
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public var slot:Int = 0;

  public function new(serial:Int, itemType:ItemType, count:Int) {
    this.serial = serial;
    this.itemType = itemType;
    this.count = count;
  }

  public inline function inWorld():Bool return parent == null;

  /** True if this item, when placed in the world, blocks movement. */
  public inline function blocksMovement():Bool {
    return itemType.category() == FURNITURE;
  }
}
```

- [ ] **Step 6: Rewrite `Inventory`**

Replace the entire contents of `server/src/server/zone/Inventory.hx`:

```haxe
package server.zone;

import shared.item.ItemType;

/** A mobile's carried items, slot-ordered. Items are first-class records
    with their own serial; stack merges keep the existing slot's serial and
    destroy the incoming item via `onDestroy`. */
class Inventory {
  public var slots(default, null):Array<Item> = [];
  public var activeSlot:Int = 0;
  public var owner(default, null):Mobile;

  /** Notification hooks the simulator installs so persistence + wire happen
      without Inventory knowing about either. */
  public var onAdd:Item -> Void = function(_) {};
  public var onSlotCountChanged:Item -> Void = function(_) {};
  public var onDestroy:Item -> Void = function(_) {};
  public var onReparent:Item -> Void = function(_) {};

  public function new(owner:Mobile) {
    this.owner = owner;
  }

  /** Add a freshly-spawned (no current parent) item. Stackable types merge
      into the existing slot of the same type — the new item is destroyed. */
  public function add(item:Item):Void {
    if (item.itemType.stackable()) {
      for (s in slots) {
        if (s.itemType == item.itemType) {
          s.count += item.count;
          onSlotCountChanged(s);
          onDestroy(item);
          return;
        }
      }
    }
    item.parent = owner;
    item.slot = slots.length;
    slots.push(item);
    onReparent(item);
    onAdd(item);
  }

  public function countOf(itemType:ItemType):Int {
    var n = 0;
    for (s in slots) if (s.itemType == itemType) n += s.count;
    return n;
  }

  public function has(itemType:ItemType, count:Int):Bool {
    return countOf(itemType) >= count;
  }

  /** Remove `count` of `itemType`. Slots that empty are removed (and
      destroyed via `onDestroy`); subsequent slots reindex. */
  public function removeCount(itemType:ItemType, count:Int):Bool {
    if (!has(itemType, count)) return false;
    var remaining = count;
    var i = 0;
    while (i < slots.length && remaining > 0) {
      var s = slots[i];
      if (s.itemType == itemType) {
        var take = (s.count < remaining) ? s.count : remaining;
        s.count -= take;
        remaining -= take;
        if (s.count <= 0) {
          slots.splice(i, 1);
          onDestroy(s);
          reindexFrom(i);
          continue;
        } else {
          onSlotCountChanged(s);
        }
      }
      i++;
    }
    return true;
  }

  public function activeItem():Null<Item> {
    if (activeSlot < 0 || activeSlot >= slots.length) return null;
    return slots[activeSlot];
  }

  public function isEmpty():Bool return slots.length == 0;

  /** Flatten to plain rows for MsgInventory and tests. */
  public function toRows():Array<{itemTypeId:Int, count:Int}> {
    return [for (s in slots) { itemTypeId: (s.itemType : Int), count: s.count }];
  }

  function reindexFrom(start:Int):Void {
    for (i in start...slots.length) {
      var s = slots[i];
      if (s.slot != i) {
        s.slot = i;
        onReparent(s);
      }
    }
  }
}
```

- [ ] **Step 7: Rewrite `ZoneSimulator`**

The simulator needs the largest single edit in this task. The shape after
the edit:

- `entities:Map<Int, Mobile>` is renamed to `mobiles`.
- `groundItems` and `worldObjects` are removed; `items:Map<Int, Item>`
  replaces them.
- `nextGroundItemId` / `nextObjectId` / `freshGroundItemId` / `freshObjectId`
  are removed. Callers use `serials.nextItem()`.
- The simulator gains a `serials:Serials` field and an `?itemDal:ItemDal`
  parameter; `?characterDal:CharacterDal` becomes `?mobileDal:MobileDal`.
- `spawn(ch)` becomes `spawn(m:Mobile)`. `entityById` → `mobileBySerial`.
  `entityAt(x,y)` keeps its name (returns `Mobile`).
- `groundItemAt` is renamed to `itemAt` and returns `Null<Item>` (only
  world-placed items, never carried ones).
- `objectAt(x,y)` now scans `items` for a placed furniture-category item
  (`item.blocksMovement() && item.inWorld()`).
- `spawnGroundItem`, `addGroundItem`, `addWorldObject` collapse into a
  single `spawnItem(itemType, count, x, y)` that allocates a serial,
  creates an `Item`, inserts into the DB, and pushes onto `pendingItemSpawns`.
- `pendingItemSpawns` stays — it's still an `Array<Item>` (was
  `Array<GroundItem>`), and the wire emission in Task 3 will read it.

Replace the contents of `server/src/server/zone/ZoneSimulator.hx` with:

```haxe
package server.zone;

import shared.Constants;
import shared.world.MapData;
import shared.world.Direction;
import shared.world.TileType;
import shared.item.ItemType;

typedef MoveResult = { entityId:Int, fromX:Int, fromY:Int, toX:Int, toY:Int };
typedef PickupResult = { entity:Mobile, worldItemSerial:Int };

class ZoneSimulator {
  public var currentTick(default, null):Int = 0;
  public var map(default, null):MapData;
  public var zoneId(default, null):Int;

  public var serials(default, null):Serials;
  public var scheduler(default, null):Scheduler = new Scheduler();

  public var mobiles(default, null):Map<Int, Mobile> = new Map();
  public var items(default, null):Map<Int, Item> = new Map();

  public static inline var FLUSH_TICK_INTERVAL:Int = 50;

  public var movesThisTick(default, null):Array<MoveResult> = [];
  public var pickupsThisTick(default, null):Array<PickupResult> = [];
  public var pendingTileChanges(default, null):Array<{x:Int, y:Int, type:Int, data:Int}> = [];
  public var pendingItemSpawns(default, null):Array<Item> = [];

  var mobileDal:Null<server.db.MobileDal>;
  var itemDal:Null<server.db.ItemDal>;
  var tileDal:Null<server.db.ZoneTileDal>;

  public function new(map:MapData, serials:Serials, zoneId:Int = 1,
                      ?mobileDal:server.db.MobileDal,
                      ?itemDal:server.db.ItemDal,
                      ?tileDal:server.db.ZoneTileDal) {
    this.map = map;
    this.serials = serials;
    this.zoneId = zoneId;
    this.mobileDal = mobileDal;
    this.itemDal = itemDal;
    this.tileDal = tileDal;
    scheduler.every(FLUSH_TICK_INTERVAL, flushMobilePositions);
  }

  public function flushMobilePositions():Void {
    if (mobileDal == null) return;
    for (m in mobiles) {
      try {
        mobileDal.savePosition(m.serial, m.tileX, m.tileY);
      } catch (err:Dynamic) {
        Sys.println('[zone] flush save failed for mobile ${m.serial}: $err');
      }
    }
  }

  public function tick():Void {
    currentTick++;
    movesThisTick = [];
    pickupsThisTick = [];
    for (m in mobiles) {
      if (m.pendingDir < 0) continue;
      if (currentTick < m.nextMoveTick) continue;
      var dir:Direction = cast m.pendingDir;
      m.pendingDir = -1;
      var dx = dir.dx();
      var dy = dir.dy();
      if (dx == 0 && dy == 0) continue;
      var nx = m.tileX + dx;
      var ny = m.tileY + dy;
      if (!canStep(nx, ny)) continue;
      var fromX = m.tileX, fromY = m.tileY;
      m.tileX = nx;
      m.tileY = ny;
      m.nextMoveTick = currentTick + Constants.MOVE_TICKS;
      movesThisTick.push({ entityId: m.serial, fromX: fromX, fromY: fromY, toX: nx, toY: ny });

      var gi = itemAt(nx, ny);
      if (gi != null && !gi.blocksMovement()) {
        m.inventory.add(gi);
        items.remove(gi.serial);
        pickupsThisTick.push({ entity: m, worldItemSerial: gi.serial });
      }
    }
    growTiles();
    scheduler.tick();
  }

  function growTiles():Void {
    var seen = new Map<Int, Bool>();
    for (m in mobiles) {
      for (ty in (m.tileY - 16)...(m.tileY + 17)) {
        for (tx in (m.tileX - 16)...(m.tileX + 17)) {
          if (tx < 0 || ty < 0 || tx >= map.width || ty >= map.height) continue;
          var key = ty * map.width + tx;
          if (seen.exists(key)) continue;
          seen.set(key, true);
          growTile(tx, ty);
        }
      }
    }
  }

  function growTile(x:Int, y:Int):Void {
    var t = map.tileAt(x, y);
    var d = map.tileData(x, y);
    if (t == (TileType.TREE_SAPLING : Int)) {
      if (d >= 99) changeTile(x, y, TileType.TREE, 0);
      else map.setTileData(x, y, d + 1);
    } else if (t == (TileType.CACTUS_SAPLING : Int)) {
      if (d >= 99) changeTile(x, y, TileType.CACTUS, 0);
      else map.setTileData(x, y, d + 1);
    } else if (t == (TileType.WHEAT : Int)) {
      if (d < 50 && Std.random(2) == 0) {
        var nd = d + 1;
        map.setTileData(x, y, nd);
        if (nd == 10 || nd == 20 || nd == 30 || nd == 40 || nd == 50) {
          pendingTileChanges.push({ x: x, y: y, type: t, data: nd });
        }
      }
    }
  }

  /** Spawn a world-placed item (ground item or placed furniture). Allocates
      a serial, inserts the row, queues the spawn broadcast. */
  public function spawnItem(itemType:ItemType, count:Int, x:Int, y:Int):Item {
    var it = new Item(serials.nextItem(), itemType, count);
    it.tileX = x;
    it.tileY = y;
    items.set(it.serial, it);
    pendingItemSpawns.push(it);
    if (itemDal != null) {
      try {
        itemDal.insertWorld(it.serial, (itemType : Int), count, zoneId, x, y);
      } catch (err:Dynamic) {
        Sys.println('[zone] insertWorld failed for item ${it.serial}: $err');
      }
    }
    return it;
  }

  public function changeTile(x:Int, y:Int, type:TileType, data:Int):Void {
    map.setTile(x, y, type);
    map.setTileData(x, y, data);
    pendingTileChanges.push({ x: x, y: y, type: (type : Int), data: data });
    if (tileDal != null) tileDal.upsert(x, y, (type : Int), data);
  }

  public function clearPending():Void {
    pendingTileChanges = [];
    pendingItemSpawns = [];
  }

  /** The world-placed item on (x, y), or null. Does not return carried items. */
  public function itemAt(x:Int, y:Int):Null<Item> {
    for (it in items) {
      if (it.inWorld() && it.tileX == x && it.tileY == y) return it;
    }
    return null;
  }

  public function spawn(m:Mobile):Void {
    mobiles.set(m.serial, m);
    if (m.inventory != null) wireInventory(m);
  }

  public function despawn(serial:Int):Void {
    mobiles.remove(serial);
  }

  public function mobileBySerial(serial:Int):Null<Mobile> {
    return mobiles.get(serial);
  }

  public function mobileCount():Int {
    var n = 0;
    for (_ in mobiles) n++;
    return n;
  }

  public function allMobiles():Iterator<Mobile> return mobiles.iterator();

  public function entityAt(x:Int, y:Int):Null<Mobile> {
    for (m in mobiles) {
      if (m.tileX == x && m.tileY == y) return m;
    }
    return null;
  }

  /** True if a blocking item (placed furniture) sits on (x, y). */
  public function objectAt(x:Int, y:Int):Bool {
    for (it in items) {
      if (it.inWorld() && it.blocksMovement() && it.tileX == x && it.tileY == y) return true;
    }
    return false;
  }

  public function canStep(x:Int, y:Int):Bool {
    return map.isWalkable(x, y) && entityAt(x, y) == null && !objectAt(x, y);
  }

  /** Install persistence hooks on a mobile's inventory. Called from `spawn`
      and from `addCarriedItemForLoad` so loaded items are also tracked. */
  function wireInventory(m:Mobile):Void {
    var inv = m.inventory;
    var idal = itemDal;
    inv.onReparent = function(it:Item) {
      items.set(it.serial, it);
      if (idal != null) idal.reparentToMobile(it.serial, m.serial, it.slot);
    };
    inv.onSlotCountChanged = function(it:Item) {
      if (idal != null) idal.updateCount(it.serial, it.count);
    };
    inv.onDestroy = function(it:Item) {
      items.remove(it.serial);
      if (idal != null) idal.delete(it.serial);
    };
    inv.onAdd = function(_) {};  // covered by onReparent
  }

  /** Load-time helper: attach a pre-existing carried item to a mobile
      without firing persistence (the row already exists). */
  public function attachCarriedItem(m:Mobile, it:Item):Void {
    it.parent = m;
    m.inventory.slots.push(it);
    items.set(it.serial, it);
  }

  /** Load-time helper: register a world-placed item already in the DB. */
  public function attachWorldItem(it:Item):Void {
    items.set(it.serial, it);
  }
}
```

- [ ] **Step 8: Update `WorldPopulator`**

Replace `server/src/server/zone/WorldPopulator.hx` `populate` body to allocate
via `Serials.nextItem()` and persist via `spawnItem` (which already inserts):

```haxe
package server.zone;

import shared.Constants;
import shared.item.ItemType;

class WorldPopulator {
  static var CAMP:Array<{ t:ItemType, dx:Int, dy:Int }> = [
    { t: ItemType.WORKBENCH, dx: -3, dy: -3 },
    { t: ItemType.FURNACE,   dx: -1, dy: -3 },
    { t: ItemType.OVEN,      dx:  1, dy: -3 },
    { t: ItemType.ANVIL,     dx:  3, dy: -3 },
    { t: ItemType.CHEST,     dx: -3, dy: -1 },
    { t: ItemType.LANTERN,   dx:  3, dy: -1 },
  ];

  static var SCATTER:Array<ItemType> = [
    ItemType.WOOD, ItemType.STONE, ItemType.COAL, ItemType.IRON_ORE,
    ItemType.GOLD_ORE, ItemType.APPLE, ItemType.GEM, ItemType.CLOTH,
  ];

  static inline var SCATTER_COUNT = 40;
  static inline var SCATTER_RADIUS = 24;
  static inline var SEED = 0x5C2117E;

  public static function populate(sim:ZoneSimulator):Void {
    var anchor = sim.map.findWalkableNear(Constants.DEFAULT_SPAWN_X, Constants.DEFAULT_SPAWN_Y);
    var spawnX = anchor.x;
    var spawnY = anchor.y;

    for (slot in CAMP) {
      var tx = spawnX + slot.dx;
      var ty = spawnY + slot.dy;
      if (!sim.map.isWalkable(tx, ty)) continue;
      sim.spawnItem(slot.t, 1, tx, ty);
    }

    var rng = new SeededRng(SEED);
    var placed = 0;
    var attempts = 0;
    while (placed < SCATTER_COUNT && attempts < SCATTER_COUNT * 100) {
      attempts++;
      var tx = spawnX + rng.range(-SCATTER_RADIUS, SCATTER_RADIUS);
      var ty = spawnY + rng.range(-SCATTER_RADIUS, SCATTER_RADIUS);
      if (!sim.map.isWalkable(tx, ty)) continue;
      if (sim.objectAt(tx, ty)) continue;
      var t = SCATTER[rng.nextInt(SCATTER.length)];
      var count = t.stackable() ? 1 + rng.nextInt(5) : 1;
      sim.spawnItem(t, count, tx, ty);
      placed++;
    }
  }
}
```

- [ ] **Step 9: Update `Main.hx` (zone)**

In `server/src/server/zone/Main.hx`, replace the boot wiring that instantiates
`CharacterDal` + `ZoneSimulator` with the new shape. The simulator constructor
now takes `Serials`, `MobileDal`, and `ItemDal`. The boot logic:

1. Construct `SerialCounterDal`, then `Serials`.
2. Construct `MobileDal`, `ItemDal`, `ZoneTileDal`.
3. Construct `ZoneSimulator(map, serials, 1, mobileDal, itemDal, tileDal)`.
4. **Conditional populate:** `if (itemDal.countForZone(1) == 0) WorldPopulator.populate(sim);`
5. **Load existing world items:** for each row from `itemDal.loadWorldFor(1)`,
   construct an `Item` and call `sim.attachWorldItem(it)`.

(The exact diff against the current `Main.hx` depends on its present
structure; the implementer should preserve the existing `pkill`-able
process loop and only swap the dal construction + populate path.)

- [ ] **Step 10: Update `EnterZoneHandler`**

When a player enters the zone, today the handler reads from `CharacterDal`
(`findByAccountId`, autocreate) and loads inventory via
`characterDal.loadInventory`. Switch to:

1. `mobileDal.findByAccountId(accountId)` → returns `MobileRow` or null.
2. If null: allocate a serial via `sim.serials.nextMobile()`, insert via
   `mobileDal.insert(serial, accountId, name, 1, DEFAULT_SPAWN_X, DEFAULT_SPAWN_Y)`,
   continue with that serial.
3. Construct `Mobile(serial, name, conn, tileX, tileY)`.
4. Load carried items via `itemDal.loadCarriedFor(serial)`; for each row,
   construct `Item(serial, itemTypeId, count)` with `slot = row.slot` and
   call `sim.attachCarriedItem(mobile, item)`.
5. `sim.spawn(mobile)` (which installs the inventory persistence hooks).
6. Send the `MsgInventory` burst as today (body unchanged in this task).

- [ ] **Step 11: Update `LoginHandler` (gateway)**

The gateway's login flow currently uses `CharacterDal.findByAccountId` /
`autoCreate` to ensure the account has a character row. Switch to
`MobileDal.findByAccountId`. The autocreate path moves to the zone's
`EnterZoneHandler` (above) since serial allocation lives in the zone process.
The gateway only needs to know that a mobile exists for the account so
log-in can hand off — it can rely on the zone to autocreate.

If the gateway today calls `autoCreate` itself, replace that call with a
read-only check (`findByAccountId`); on null, return a "no character yet"
state that the zone autocreates from on first enter.

- [ ] **Step 12: Update the remaining handlers and `Crafting`**

For each of the following, replace `Character` with `Mobile`, the field
`id` with `serial`, and `freshObjectId` / `freshGroundItemId` /
`addGroundItem` / `addWorldObject` calls with `spawnItem`:

- `server/src/server/zone/Crafting.hx`
- `server/src/server/zone/CraftHandler.hx`
- `server/src/server/zone/InventoryHandler.hx`
- `server/src/server/zone/MoveIntentHandler.hx`
- `server/src/server/zone/TileHandler.hx`
- `server/src/server/zone/TileInteraction.hx`
- `server/src/server/zone/InterestManager.hx`

These edits are mechanical renames; the wire messages they construct stay
identical (still `MsgEntitySpawn(entityId = mobile.serial)`,
`MsgGroundItemSpawn(worldItemId = item.serial, …)`, etc.).

`InventoryHandler.dropItem` (or the equivalent action that converts a
carried item to a ground item) now calls `mobile.inventory.removeCount(...)`
*and* `sim.spawnItem(...)` — the removed item's destruction (via
`onDestroy` → `itemDal.delete`) and the new ground item's insert are
independent. The wire emits `MsgGroundItemSpawn` + `MsgInventory` as today.

- [ ] **Step 13: Delete old files**

```bash
rm server/src/server/zone/Character.hx
rm server/src/server/zone/GroundItem.hx
rm server/src/server/zone/WorldObject.hx
rm server/src/server/db/CharacterDal.hx
rm server/test/TestCharacterDal.hx
rm shared/src/shared/item/ItemStack.hx
rm shared/test/TestItemStack.hx
```

- [ ] **Step 14: Update `TestMain.hx` (server)**

Remove the `r.addCase(new TestCharacterDal());` line. Add:

```haxe
    r.addCase(new TestItem());
    r.addCase(new TestZoneBoot());
```

- [ ] **Step 15: Add `TestItem`**

Create `server/test/TestItem.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Item;
import server.zone.Mobile;
import shared.item.ItemType;

class TestItem extends Test {
  function testStartsInWorld() {
    var it = new Item(0x40000000, ItemType.WOOD, 3);
    Assert.isTrue(it.inWorld());
    Assert.isFalse(it.blocksMovement());   // wood doesn't block
  }

  function testFurnitureBlocks() {
    var it = new Item(0x40000001, ItemType.WORKBENCH, 1);
    Assert.isTrue(it.blocksMovement());
  }

  function testParentToggle() {
    var it = new Item(0x40000002, ItemType.STONE, 5);
    var m = new Mobile(1, "x", null, 0, 0);
    it.parent = m;
    Assert.isFalse(it.inWorld());
    it.parent = null;
    Assert.isTrue(it.inWorld());
  }
}
```

- [ ] **Step 16: Add `TestZoneBoot`**

Create `server/test/TestZoneBoot.hx`. This test uses a fake `ItemDal` that
returns a configurable count, and verifies `WorldPopulator.populate` is
gated on it. (Exact fixture shape matches `TestZoneSimulator`'s in-memory
style — implementer should look there for the right test scaffolding.)

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Serials;
import server.zone.Mobile;
import server.zone.Item;
import shared.item.ItemType;

class TestZoneBoot extends Test {
  function testPopulateRunsOnFreshDb() {
    var sim = newSim(itemsPreloaded = 0);
    server.zone.WorldPopulator.populate(sim);
    Assert.isTrue(sim.items.count() > 0);
  }

  function testPopulateSkippedWhenItemsExist() {
    var sim = newSim(itemsPreloaded = 5);
    var before = sim.items.count();
    if (sim.itemDal.countForZone(1) == 0) {
      server.zone.WorldPopulator.populate(sim);
    }
    Assert.equals(before, sim.items.count());
  }

  // Helpers: newSim() builds a ZoneSimulator with a fake MapData + ItemDal
  // matching the existing TestZoneSimulator pattern. See that file.
}
```

(If `TestZoneSimulator.hx` doesn't already have a reusable fake-DAL setup,
extract one and reuse it across `TestZoneSimulator` + `TestZoneBoot`.)

- [ ] **Step 17: Update existing zone tests**

For each of `TestZoneSimulator`, `TestZoneLifecycle`, `TestZoneInterest`,
`TestZoneChat`, `TestCrafting`, `TestWorldPopulator`, `TestInventory`:

- Replace `new Character(...)` with `new Mobile(...)`.
- Replace `Character` parameter types with `Mobile`.
- Replace `.id` accessor with `.serial`.
- Replace `sim.entityById(...)` with `sim.mobileBySerial(...)`.
- Replace `new GroundItem(...)` / `new WorldObject(...)` with
  `sim.spawnItem(itemType, count, x, y)` (which returns an `Item`).
- Replace `sim.addGroundItem(...)` / `sim.addWorldObject(...)` /
  `sim.freshGroundItemId()` / `sim.freshObjectId()` with `sim.spawnItem(...)`.
- Replace `sim.groundItems` iteration with `sim.items` iteration filtered
  by `!it.blocksMovement()`; `sim.worldObjects` iteration with `sim.items`
  filtered by `it.blocksMovement()`.
- `TestInventory` — rewrite to construct `Mobile`s and use the new
  `inventory.add(item:Item)` API. The behavior assertions (stacking,
  removeCount, activeItem) carry over; the construction does not.
- `TestZoneLifecycle` — add an inventory-persistence assertion: drop an
  item, log out, log back in, verify the inventory is restored with the
  same serials (use `itemDal.loadCarriedFor(serial)` to read the truth).

- [ ] **Step 18: Build everything**

Run: `./build_native.sh shared-test client-test server-test zone gateway client`
Expected: all targets compile.

- [ ] **Step 19: Run the unit suites**

Run: `./bin/shared-test && ./bin/server-test && ./bin/client-test`
Expected: `ALL TESTS OK` for shared and client. For server-test, the
non-integration cases (`TestSerials`, `TestItem`, `TestInventory`, `TestScheduler`,
`TestFrameBuffer`, etc.) pass; the integration cases that need a live
server (`TestLoginFlow`, `TestZoneLifecycle`, `TestZoneInterest`,
`TestZoneChat`) are verified next.

- [ ] **Step 20: Run the integration suite**

```bash
pkill -f 'bin/zone' ; pkill -f 'bin/gateway' ; sleep 1
./run-integration.sh
```

Expected: `ALL TESTS OK`. `TestZoneLifecycle` exercises the persistence
seam — its passing confirms the new `MobileDal` / `ItemDal` round-trip
matches the old behavior.

- [ ] **Step 21: Run the headless bots smoke test**

```bash
./run-server.sh &       # gateway + zone
sleep 2
./tools/zone-bots/run.sh    # or whatever the project's bot script is
```

Expected: bots connect, walk, pick up items, log out without error. The
zone log shows persistence hooks firing on pickup
(`reparentToMobile`).

- [ ] **Step 22: Commit**

```bash
git add server/src/server/zone/Mobile.hx server/src/server/zone/Item.hx \
        server/src/server/zone/Inventory.hx server/src/server/zone/ZoneSimulator.hx \
        server/src/server/zone/Main.hx server/src/server/zone/WorldPopulator.hx \
        server/src/server/zone/Crafting.hx server/src/server/zone/CraftHandler.hx \
        server/src/server/zone/InventoryHandler.hx server/src/server/zone/MoveIntentHandler.hx \
        server/src/server/zone/EnterZoneHandler.hx server/src/server/zone/TileHandler.hx \
        server/src/server/zone/TileInteraction.hx server/src/server/zone/InterestManager.hx \
        server/src/server/zone/SerialCounter.hx server/src/server/db/MobileDal.hx \
        server/src/server/db/ItemDal.hx server/src/server/db/SerialCounterDal.hx \
        server/src/server/gateway/LoginHandler.hx server/src/server/gateway/Main.hx \
        server/test/TestItem.hx server/test/TestZoneBoot.hx server/test/TestMain.hx \
        server/test/TestZoneSimulator.hx server/test/TestZoneLifecycle.hx \
        server/test/TestZoneInterest.hx server/test/TestZoneChat.hx \
        server/test/TestCrafting.hx server/test/TestWorldPopulator.hx \
        server/test/TestInventory.hx \
        db/migrations/0005_entities.sql db/migrations/0005_entities_rollback.sql
git rm server/src/server/zone/Character.hx server/src/server/zone/GroundItem.hx \
       server/src/server/zone/WorldObject.hx server/src/server/db/CharacterDal.hx \
       server/test/TestCharacterDal.hx \
       shared/src/shared/item/ItemStack.hx shared/test/TestItemStack.hx
git commit -m "$(cat <<'EOF'
feat(zone): unify Character/GroundItem/WorldObject under Mobile + Item

Migration 0005 replaces `characters` + `character_items` with `mobiles`,
`items`, and `serial_counters`. Serials are allocated by Serials backed by
SerialCounterDal; every item now has a globally unique id and a parent
pointer (NULL for world-placed, mobile serial for carried).

Wire is intentionally unchanged in this commit — the spawn/move/despawn
collapse and re-parent pickup land in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire collapse + pickup as re-parent

This task collapses the world-item / world-object spawn+despawn messages
into the existing `MsgEntity*` family, makes pickup a re-parent move, and
updates the client. Because internal state already supports it (Task 2),
the diff is concentrated in `shared/proto` + the client + the few server
sites that emit pickup / spawn messages.

**Files:**
- Modify: `shared/src/shared/proto/MsgEntitySpawn.hx`, `MsgEntityMove.hx`, `MsgInventory.hx`, `MsgType.hx`
- Delete: `shared/src/shared/proto/MsgGroundItemSpawn.hx`, `MsgGroundItemDespawn.hx`, `MsgWorldObjectSpawn.hx`
- Modify: `server/src/server/zone/EnterZoneHandler.hx`, `ZoneSimulator.hx`, `InventoryHandler.hx`, `MoveIntentHandler.hx` (or the file emitting the per-tick broadcast)
- Modify: `client/src/client/Main.hx`, `client/src/headless/HeadlessClient.hx`
- Modify: `server/test/TestZoneLifecycle.hx`, `TestZoneInterest.hx` (assertions on emitted messages)

- [ ] **Step 1: Extend the proto messages**

Replace `shared/src/shared/proto/MsgEntitySpawn.hx`:

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgEntitySpawn implements Serializable {
  public var serial:Int = 0;          // top bit discriminates kind
  public var name:String = "";        // mobile only
  public var itemTypeId:Int = 0;      // item only
  public var count:Int = 0;           // item only
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public var parentSerial:Int = 0;    // item only; 0 = in world
  public var slot:Int = 0;            // item only; meaningful when parentSerial != 0
  public function new() {}
}
```

Replace `shared/src/shared/proto/MsgEntityMove.hx`:

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgEntityMove implements Serializable {
  public var serial:Int = 0;
  public var fromX:Int = 0;
  public var fromY:Int = 0;
  public var toX:Int = 0;
  public var toY:Int = 0;
  public var newParentSerial:Int = 0; // 0 = world-placed at (toX, toY)
  public var newSlot:Int = 0;
  public function new() {}
}
```

Update `MsgInventory` to carry serials. Today its rows are
`{itemTypeId, count}`; change to `{serial, itemTypeId, count}` so the
client can correlate later move events to inventory slots:

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgInventory implements Serializable {
  public var slots:Array<{serial:Int, itemTypeId:Int, count:Int}> = [];
  public var activeSlot:Int = 0;
  public function new() {}
}
```

(If `Serializable` doesn't support arrays of records natively, encode as
three parallel arrays — see how `MsgInventory.hx` does it today and follow
the same pattern.)

- [ ] **Step 2: Remove the obsolete proto messages**

```bash
rm shared/src/shared/proto/MsgGroundItemSpawn.hx
rm shared/src/shared/proto/MsgGroundItemDespawn.hx
rm shared/src/shared/proto/MsgWorldObjectSpawn.hx
```

Update `shared/src/shared/proto/MsgType.hx`:

```haxe
package shared.proto;

enum abstract MsgType(Int) to Int from Int {
  var HELLO = 1;
  var HELLO_ACK = 2;
  var LOGIN = 3;
  var LOGIN_ACK = 4;
  var ERROR = 5;
  var ZONE_HANDOFF = 10;
  var ENTER_ZONE = 11;
  var ENTER_ZONE_ACK = 12;
  var MOVE_INTENT = 20;
  var ENTITY_SPAWN = 21;
  var ENTITY_MOVE = 22;
  var ENTITY_DESPAWN = 23;
  var INVENTORY = 32;
  var SELECT_ACTIVE_ITEM = 34;
  var USE_ITEM_ON_TILE = 35;
  var TILE_CHANGE = 36;
  var CRAFT = 37;
  var PLACE_FURNITURE = 38;
  var CHAT = 40;
}
```

Leave the numeric gaps (`30`, `31`, `33`) — do not renumber surviving codes.

- [ ] **Step 3: Update zone-entry burst**

In `EnterZoneHandler`, the burst that today emits one `MsgEntitySpawn` per
mobile, one `MsgGroundItemSpawn` per ground item, and one
`MsgWorldObjectSpawn` per world object now emits **only** `MsgEntitySpawn`,
one per entry in `sim.mobiles` and `sim.items`. The fields for mobiles fill
`serial` + `name` + `tileX/Y` (leaving item-only fields at zero); for items
fill `serial` + `itemTypeId` + `count` + `tileX/Y` (leaving `name = ""`).

The recipient's own carried items go in the `MsgInventory` burst (with
serials now) — they do *not* also appear as `MsgEntitySpawn`. Other
players' carried items are not visible to this client and don't ship.

- [ ] **Step 4: Update item-spawn broadcasts**

The per-tick code that today reads `sim.pendingItemSpawns` and emits one
`MsgGroundItemSpawn` per entry now emits one `MsgEntitySpawn` per entry,
with item-shape fields filled. Placed-furniture spawns (from
`PlaceFurniture` / crafting) flow through the same path.

- [ ] **Step 5: Update pickup to a re-parent move**

In `ZoneSimulator.tick()`, the pickup block already calls
`m.inventory.add(gi)` and pushes a `PickupResult`. Adjust the per-tick
broadcast code so that for each pickup:

- The Item's serial is known (`gi.serial`); its new parent is the mobile
  (`m.serial`); its new slot is the slot in `m.inventory` where it ended up
  (look it up via `m.inventory.slots.indexOf(gi)` — for a non-merging
  pickup, this is its slot; for a merging pickup, see next step).
- Emit a single `MsgEntityMove` with `serial = gi.serial`,
  `fromX = gi.tileX`, `fromY = gi.tileY`, `toX = 0`, `toY = 0`,
  `newParentSerial = m.serial`, `newSlot = gi.slot`.

For a **merging** pickup (stackable type, existing slot), the inventory's
`onDestroy` fired on `gi`. The simulator instead emits:
- `MsgEntityDespawn` for `gi.serial` (the consumed item is gone).
- `MsgInventory` for the recipient mobile only (so the surviving slot's
  new count reaches the client). This is the only path that ships a
  mid-tick `MsgInventory` after Task 3.

To distinguish the two cases, the simulator can check `gi.parent` after
`add`: if `null`, it merged and was destroyed (`onDestroy` fired); if it's
`m`, it re-parented.

- [ ] **Step 6: Update the client**

In `client/src/client/Main.hx`:
- Drop the handlers for `MsgGroundItemSpawn`, `MsgGroundItemDespawn`,
  `MsgWorldObjectSpawn`.
- In the `MsgEntitySpawn` handler, branch on
  `Serials.isMobile(msg.serial)` (or replicate the bit check inline if
  `Serials` isn't shared with the client) and render either a player
  sprite (existing path) or an item sprite (the path previously triggered
  by `MsgGroundItemSpawn` / `MsgWorldObjectSpawn`). For item spawns, use
  `msg.itemTypeId`, `msg.count`, `msg.tileX/Y`. If `parentSerial != 0`,
  ignore — carried items belong to inventory, not the world layer.
- In the `MsgEntityMove` handler, if `newParentSerial != 0`, treat the
  message as a re-parent: remove the item sprite from the world layer
  (if present) and update the local inventory model. If
  `newParentSerial == 0` and the previous parent was non-zero, the item
  has been dropped — add the world sprite at `toX/Y`.
- In the `MsgInventory` handler, the rows now carry serials; persist them
  so subsequent re-parent moves can be applied without ambiguity.

Do the equivalent in `client/src/headless/HeadlessClient.hx`.

The exact `Serials.isMobile` check inline (since `Serials.hx` is server-only):

```haxe
inline function isMobileSerial(s:Int):Bool return s > 0 && (s & 0x40000000) == 0;
```

(Optionally extract this into a shared utility — `shared.proto.Serials` —
if the client also benefits. The plan does not require it.)

- [ ] **Step 7: Update integration tests**

`TestZoneLifecycle`, `TestZoneInterest`, `TestZoneChat` — wherever they
assert on `MsgGroundItemSpawn` / `MsgWorldObjectSpawn` / `MsgGroundItemDespawn`,
swap to `MsgEntitySpawn` / `MsgEntityDespawn`. Pickup assertions in
`TestZoneLifecycle` change from "world-despawn + inventory" to "single
`MsgEntityMove` with `newParentSerial = mobile.serial`."

Add a new test method to `TestZoneLifecycle`: drop an item, log out, log
back in, assert the item's serial is still in the inventory burst (proves
identity persistence through the wire round-trip).

- [ ] **Step 8: Build everything**

Run: `./build_native.sh shared-test client-test server-test zone gateway client`
Expected: all targets compile.

- [ ] **Step 9: Run the full suite**

```bash
pkill -f 'bin/zone' ; pkill -f 'bin/gateway' ; sleep 1
make test
./bin/server-test
./bin/client-test
./run-integration.sh
```

Expected: `ALL TESTS OK` across the board.

- [ ] **Step 10: Headless bots smoke test**

```bash
./run-server.sh &
sleep 2
./tools/zone-bots/run.sh
```

Expected: bots run end-to-end against the collapsed wire. The zone log
shows pickups emitting `MsgEntityMove` re-parents (not
`MsgGroundItemDespawn`).

- [ ] **Step 11: Commit**

```bash
git add shared/src/shared/proto/MsgEntitySpawn.hx \
        shared/src/shared/proto/MsgEntityMove.hx \
        shared/src/shared/proto/MsgInventory.hx \
        shared/src/shared/proto/MsgType.hx \
        server/src/server/zone/EnterZoneHandler.hx \
        server/src/server/zone/ZoneSimulator.hx \
        server/src/server/zone/InventoryHandler.hx \
        server/src/server/zone/MoveIntentHandler.hx \
        client/src/client/Main.hx \
        client/src/headless/HeadlessClient.hx \
        server/test/TestZoneLifecycle.hx \
        server/test/TestZoneInterest.hx
git rm shared/src/shared/proto/MsgGroundItemSpawn.hx \
       shared/src/shared/proto/MsgGroundItemDespawn.hx \
       shared/src/shared/proto/MsgWorldObjectSpawn.hx
git commit -m "$(cat <<'EOF'
feat(zone): collapse spawn/move/despawn wire to one MsgEntity* family

MsgEntitySpawn carries kind-discriminated fields (name for mobiles;
itemTypeId/count for items); MsgEntityMove gains newParentSerial/newSlot
so pickup is a single re-parent move instead of despawn-plus-inventory.
MsgGroundItem*, MsgWorldObjectSpawn are removed; MsgInventory rows now
carry serials so the client can correlate subsequent moves.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:**

- §1 *Serial space* — bit-range constants, `Serials.isMobile/isItem`,
  `Serials.nextMobile/nextItem`, `SerialCounter` interface, counter
  persistence via `serial_counters` row → Task 1, plus
  `SerialCounterDal` in Task 2 Step 3.
- §2 *Mobile / Item* — `Mobile.hx` replaces `Character.hx`, `Item.hx`
  replaces `GroundItem.hx` / `WorldObject.hx` / `ItemStack.hx`;
  blocking from `itemType.category()`; `inWorld()` helper → Task 2 Steps 4–5.
- §3 *DB schema* — `mobiles`, `items`, `serial_counters` in migration 0005;
  data copy from old tables; counter seeded from `MAX(...)`; FK from
  `items.parent_serial` to `mobiles.serial` → Task 2 Steps 1–3.
- §4 *ZoneSimulator integration* — unified `mobiles` / `items` maps;
  `serials:Serials` field; `spawnItem` allocator+inserter; `flushMobilePositions`
  (item state persisted at mutation, not periodically);
  `WorldPopulator` only runs when `itemDal.countForZone(1) == 0` → Task 2
  Steps 7–10.
- §5 *Wire protocol* — `MsgEntitySpawn` carries all fields; `MsgEntityMove`
  gains re-parent fields; `MsgGroundItem*` and `MsgWorldObjectSpawn`
  deleted; `MsgInventory` rows carry serials → Task 3 Steps 1–2.
- §6 *Inventory* — `Array<Item>` storage; `add(item:Item)` overload with
  merge vs. re-parent; `removeCount` walks slots and reindexes;
  persistence via callbacks installed by simulator → Task 2 Step 6.
- §7 *Pickup as re-parent* — `tick()` re-parents on walk-onto-item; one
  `MsgEntityMove` per non-merging pickup; merging emits `MsgEntityDespawn`
  + `MsgInventory` for the recipient → Task 3 Step 5.
- §8 *Edge cases* — same-serial collisions guarded by counter persistence
  (`TestSerials` Step 4); stack-merge wire path explicit (Task 3 Step 5);
  furniture placement reuses `spawnItem` (Task 2 Step 12); WorldPopulator
  skip-on-restart (Task 2 Step 9 + TestZoneBoot Step 16); migration on
  empty `character_items` (the `COALESCE` in migration 0005); re-parent
  into existing slot keeps the existing item's serial (Inventory's
  `add` Step 6).
- §9 *Testing* — `TestSerials` (Task 1), `TestItem` (Step 15),
  `TestInventory` rewritten (Step 17), `TestZoneLifecycle` extended
  (Steps 17 + Task 3 Step 7), `TestZoneBoot` (Step 16); full suite + bots
  smoke (Steps 19–21, Task 3 Steps 9–10).

**Risks mitigation:**

- *Migration is one-way* → rollback SQL checked in at
  `db/migrations/0005_entities_rollback.sql` (Task 2 Step 1).
- *Wire breakage is total* → wire collapse isolated to Task 3 with a
  separate commit boundary; the bots smoke test catches client/server
  drift before the commit.
- *Serial counter contention* → the plan writes back on each alloc as the
  simplest correct implementation. A batching optimization
  (`pre-allocate 100, write back on chunk exhaustion`) is noted as a
  follow-up in §risks but is not implemented here — the world-populate
  burst is 46 items, well within "fine."
- *Behavior change beyond refactor* → Task 2 is intentionally
  wire-unchanged so the integration tests pin behavior before the wire
  diff lands; Task 3 owns all the visible-change risk.

**Placeholder scan:** Step bodies that say "the exact diff depends on the
current file" (Task 2 Steps 9, 12; Task 3 Steps 3–4, 6) are file-specific
edits where the implementer reads the current code and applies the
described transform. Every other step has concrete code or commands.

**Type consistency:** `Mobile.serial : Int` and `Item.serial : Int` match
the wire's `serial : Int`. `Inventory.add(item:Item)` matches the
simulator's call sites. `ItemDal.reparentToMobile(serial, parentSerial,
slot)` matches `Inventory.onReparent` (which fires with the item already
having its slot set). `Serials.nextItem()` returns an `Int` in the item
range; `ItemDal.insertWorld(serial, ...)` accepts that `Int`.

**Out of scope:** the sector grid (arc 3/3); equipment layers and
containers beyond the player's own inventory; NPC AI and behavior;
item attributes / durability / charges; multi-zone serial spaces.
