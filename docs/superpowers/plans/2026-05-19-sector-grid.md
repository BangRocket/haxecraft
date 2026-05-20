# Sector Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fixed-size sector grid as the spatial index for `ZoneSimulator`, replacing the linear scans in `entityAt` / `itemAt` / `objectAt` / `canStep` and the O(n²) per-tick sweep in `InterestManager.update`.

**Architecture:** A pure `SectorGrid` holds a 2D array of `Sector` cells (8×8 tiles each) plus two `Map<serial, Sector>` membership indices. The simulator delegates tile lookups to the grid and calls into it from the five position-mutation sites (spawn, despawn, spawnItem, attachWorldItem, tick-step move) plus the inventory `onReparent` / `onDestroy` hooks. `InterestManager.update` walks only the AOI sector neighborhood for each observer.

**Tech Stack:** Haxe 4.3, HashLink (HLC native on Apple Silicon), utest.

**Spec:** `docs/superpowers/specs/2026-05-19-sector-grid-design.md`

---

## File Structure

**New files:**
- `server/src/server/zone/Sector.hx` — a single grid cell with `mobiles` + `items` arrays.
- `server/src/server/zone/SectorGrid.hx` — the grid + add/move/remove API + sector neighborhood iteration.
- `server/test/TestSectorGrid.hx` — unit tests.

**Modified files:**
- `server/test/TestMain.hx` — register `TestSectorGrid`.
- `server/src/server/zone/ZoneSimulator.hx` — own a `SectorGrid`; delegate `entityAt` / `itemAt` / `objectAt`; instrument the five mutation sites; rewire inventory hooks to remove from the grid on pickup/destroy.
- `server/src/server/zone/InterestManager.hx` — `update` takes a `SectorGrid` and walks AOI sectors.
- `server/src/server/zone/Main.hx` — `interest.update(...)` call site picks up the new signature.
- `server/test/TestInterestManager.hx` — pass a grid + register mobiles in it.

This is the third and final sub-project of the UO-patterns arc.

---

## Task 1: `SectorGrid` + `Sector`

**Files:**
- Create: `server/src/server/zone/Sector.hx`, `server/src/server/zone/SectorGrid.hx`
- Create: `server/test/TestSectorGrid.hx`
- Modify: `server/test/TestMain.hx`

- [ ] **Step 1: Write the failing tests**

Create `server/test/TestSectorGrid.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Sector;
import server.zone.SectorGrid;
import server.zone.Mobile;
import server.zone.Item;
import shared.item.ItemType;

class TestSectorGrid extends Test {
  function testMobileAddAndLookup() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 12, 9);
    g.addMobile(m);
    Assert.equals(m, g.mobileAt(12, 9));
    Assert.isNull(g.mobileAt(13, 9));
  }

  function testMobileMoveSameSector() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 0, 0);
    g.addMobile(m);
    g.moveMobile(m, 0, 0, 7, 7);   // both within sector (0,0)
    m.tileX = 7; m.tileY = 7;
    Assert.isNull(g.mobileAt(0, 0));
    Assert.equals(m, g.mobileAt(7, 7));
  }

  function testMobileMoveAcrossSectorBoundary() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 7, 0);     // sector (0,0)
    g.addMobile(m);
    g.moveMobile(m, 7, 0, 8, 0);                // sector (1,0)
    m.tileX = 8; m.tileY = 0;
    Assert.isNull(g.mobileAt(7, 0));
    Assert.equals(m, g.mobileAt(8, 0));
  }

  function testMobileRemove() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 5, 5);
    g.addMobile(m);
    g.removeMobile(m.serial);
    Assert.isNull(g.mobileAt(5, 5));
  }

  function testItemAddAndBlocking() {
    var g = new SectorGrid(64, 64);
    var bench = new Item(0x40000001, ItemType.WORKBENCH, 1);
    bench.tileX = 10; bench.tileY = 10;
    var wood = new Item(0x40000002, ItemType.WOOD, 3);
    wood.tileX = 12; wood.tileY = 10;
    g.addItem(bench);
    g.addItem(wood);

    Assert.equals(bench, g.itemAt(10, 10));
    Assert.equals(wood, g.itemAt(12, 10));
    Assert.isTrue(g.blockingItemAt(10, 10));      // furniture blocks
    Assert.isFalse(g.blockingItemAt(12, 10));     // resource doesn't
  }

  function testItemRemove() {
    var g = new SectorGrid(64, 64);
    var w = new Item(0x40000001, ItemType.WOOD, 1);
    w.tileX = 3; w.tileY = 3;
    g.addItem(w);
    g.removeItem(w.serial);
    Assert.isNull(g.itemAt(3, 3));
    Assert.isFalse(g.blockingItemAt(3, 3));
  }

  function testSameTileMobileAndItem() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 4, 4);
    var w = new Item(0x40000001, ItemType.WOOD, 1);
    w.tileX = 4; w.tileY = 4;
    g.addMobile(m);
    g.addItem(w);
    Assert.equals(m, g.mobileAt(4, 4));
    Assert.equals(w, g.itemAt(4, 4));
  }

  function testSectorsInRangeCoversNeighborhood() {
    var g = new SectorGrid(128, 128);
    // A center at tile (40,40) is in sector (5,5). A tile radius of 10
    // gives a sector radius of ceil(10/8) = 2, so the 5x5 sector window
    // (sx 3..7, sy 3..7) = 25 sectors.
    var seen = new Map<Int, Bool>();
    for (sec in g.sectorsInRange(40, 40, 10)) {
      var key = sec.sy * 1000 + sec.sx;
      Assert.isFalse(seen.exists(key));    // no duplicates
      seen.set(key, true);
    }
    var count = 0;
    for (_ in seen.keys()) count++;
    Assert.equals(25, count);
  }

  function testSectorsInRangeClampsAtMapEdge() {
    var g = new SectorGrid(64, 64);
    // Center at (0,0) with radius 8 wants sectors (-1,-1)..(1,1) but
    // clamps to (0,0)..(1,1) = 4 sectors.
    var n = 0;
    for (_ in g.sectorsInRange(0, 0, 8)) n++;
    Assert.equals(4, n);
  }

  function testMobileAtOffMapReturnsNull() {
    var g = new SectorGrid(64, 64);
    Assert.isNull(g.mobileAt(-1, 0));
    Assert.isNull(g.mobileAt(64, 0));
    Assert.isNull(g.mobileAt(0, 999));
  }
}
```

Register it in `server/test/TestMain.hx` — add after `TestZoneBoot`:

```haxe
    r.addCase(new TestZoneBoot());
    r.addCase(new TestSectorGrid());
```

- [ ] **Step 2: Run the build to verify it fails**

Run: `./build_native.sh server-test`
Expected: FAIL — compile error, `server.zone.Sector` and `server.zone.SectorGrid` not found.

- [ ] **Step 3: Create `Sector`**

Create `server/src/server/zone/Sector.hx`:

```haxe
package server.zone;

/** A single cell of the `SectorGrid`. Holds the world-placed entities
    whose tile falls inside the cell's 8x8 footprint. Mobiles and items
    are kept in separate arrays so kind-specific lookups don't scan the
    other kind. */
class Sector {
  public var sx:Int;
  public var sy:Int;
  public var mobiles:Array<Mobile> = [];
  public var items:Array<Item> = [];

  public function new(sx:Int, sy:Int) {
    this.sx = sx;
    this.sy = sy;
  }
}
```

- [ ] **Step 4: Create `SectorGrid`**

Create `server/src/server/zone/SectorGrid.hx`:

```haxe
package server.zone;

import shared.item.ItemCategory;

/**
 * Fixed-size spatial index over the zone. Sectors are 8x8 tiles. Tile
 * lookups (`mobileAt` / `itemAt` / `blockingItemAt`) scan a single
 * sector's lists; AOI sweeps (`sectorsInRange`) bound iteration to the
 * sector neighborhood instead of the full entity collection.
 *
 * Membership is tracked in two `Map<serial, Sector>` indices so removal
 * and re-keying are O(1) without searching.
 *
 * The grid is rebuilt in-memory on every boot — there is no persistence.
 */
class SectorGrid {
  public static inline var SECTOR_SIZE:Int = 8;
  public static inline var SECTOR_SHIFT:Int = 3;   // SECTOR_SIZE = 1 << SECTOR_SHIFT

  public var widthSectors(default, null):Int;
  public var heightSectors(default, null):Int;
  public var mapWidth(default, null):Int;
  public var mapHeight(default, null):Int;

  var sectors:Array<Sector>;                              // row-major
  var mobileLoc:Map<Int, Sector> = new Map();
  var itemLoc:Map<Int, Sector> = new Map();

  public function new(mapWidthTiles:Int, mapHeightTiles:Int) {
    this.mapWidth = mapWidthTiles;
    this.mapHeight = mapHeightTiles;
    this.widthSectors = (mapWidthTiles + SECTOR_SIZE - 1) >> SECTOR_SHIFT;
    this.heightSectors = (mapHeightTiles + SECTOR_SIZE - 1) >> SECTOR_SHIFT;
    this.sectors = [];
    for (sy in 0...heightSectors) {
      for (sx in 0...widthSectors) sectors.push(new Sector(sx, sy));
    }
  }

  // ---- Mobile ops ----------------------------------------------------

  public function addMobile(m:Mobile):Void {
    var sec = sectorAt(m.tileX, m.tileY);
    if (sec == null) return;
    sec.mobiles.push(m);
    mobileLoc.set(m.serial, sec);
  }

  /** Re-key a mobile that just moved from (fromX,fromY) to (toX,toY).
      Callers must update `m.tileX/m.tileY` to (toX,toY) before or after;
      this method doesn't read them. */
  public function moveMobile(m:Mobile, fromX:Int, fromY:Int, toX:Int, toY:Int):Void {
    var fromKey = (fromY >> SECTOR_SHIFT) * widthSectors + (fromX >> SECTOR_SHIFT);
    var toKey   = (toY   >> SECTOR_SHIFT) * widthSectors + (toX   >> SECTOR_SHIFT);
    if (fromKey == toKey) return;   // same sector — no move needed
    var oldSec = mobileLoc.get(m.serial);
    if (oldSec != null) oldSec.mobiles.remove(m);
    var newSec = sectorAt(toX, toY);
    if (newSec == null) {
      mobileLoc.remove(m.serial);
      return;
    }
    newSec.mobiles.push(m);
    mobileLoc.set(m.serial, newSec);
  }

  public function removeMobile(serial:Int):Void {
    var sec = mobileLoc.get(serial);
    if (sec == null) return;
    for (m in sec.mobiles) {
      if (m.serial == serial) { sec.mobiles.remove(m); break; }
    }
    mobileLoc.remove(serial);
  }

  // ---- Item ops ------------------------------------------------------

  public function addItem(it:Item):Void {
    if (!it.inWorld()) return;
    var sec = sectorAt(it.tileX, it.tileY);
    if (sec == null) return;
    sec.items.push(it);
    itemLoc.set(it.serial, sec);
  }

  public function removeItem(serial:Int):Void {
    var sec = itemLoc.get(serial);
    if (sec == null) return;
    for (it in sec.items) {
      if (it.serial == serial) { sec.items.remove(it); break; }
    }
    itemLoc.remove(serial);
  }

  // ---- Lookups -------------------------------------------------------

  public function mobileAt(x:Int, y:Int):Null<Mobile> {
    var sec = sectorAt(x, y);
    if (sec == null) return null;
    for (m in sec.mobiles) {
      if (m.tileX == x && m.tileY == y) return m;
    }
    return null;
  }

  public function itemAt(x:Int, y:Int):Null<Item> {
    var sec = sectorAt(x, y);
    if (sec == null) return null;
    for (it in sec.items) {
      if (it.inWorld() && it.tileX == x && it.tileY == y) return it;
    }
    return null;
  }

  public function blockingItemAt(x:Int, y:Int):Bool {
    var sec = sectorAt(x, y);
    if (sec == null) return false;
    for (it in sec.items) {
      if (it.inWorld() && it.blocksMovement() && it.tileX == x && it.tileY == y) return true;
    }
    return false;
  }

  /** Iterate sectors covering an axis-aligned neighborhood around
      `(centerX, centerY)` of `tileRadius` tiles. Clamped to the grid. */
  public function sectorsInRange(centerX:Int, centerY:Int, tileRadius:Int):Iterator<Sector> {
    var sectorRadius = (tileRadius + SECTOR_SIZE - 1) >> SECTOR_SHIFT;
    var cx = centerX >> SECTOR_SHIFT;
    var cy = centerY >> SECTOR_SHIFT;
    var minSx = cx - sectorRadius; if (minSx < 0) minSx = 0;
    var minSy = cy - sectorRadius; if (minSy < 0) minSy = 0;
    var maxSx = cx + sectorRadius; if (maxSx >= widthSectors) maxSx = widthSectors - 1;
    var maxSy = cy + sectorRadius; if (maxSy >= heightSectors) maxSy = heightSectors - 1;
    var out:Array<Sector> = [];
    for (sy in minSy...(maxSy + 1)) {
      for (sx in minSx...(maxSx + 1)) {
        out.push(sectors[sy * widthSectors + sx]);
      }
    }
    return out.iterator();
  }

  // ---- Internals -----------------------------------------------------

  inline function sectorAt(x:Int, y:Int):Null<Sector> {
    if (x < 0 || y < 0 || x >= mapWidth || y >= mapHeight) return null;
    return sectors[(y >> SECTOR_SHIFT) * widthSectors + (x >> SECTOR_SHIFT)];
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `./build_native.sh server-test && ./bin/server-test`
Expected: `TestSectorGrid` — all 9 cases green. Existing integration tests
that need a live server (`TestLoginFlow`, `TestZoneLifecycle`,
`TestZoneInterest`, `TestZoneChat`) still error without one — not this
task's concern; verified via integration run in Task 2.

- [ ] **Step 6: Commit**

```bash
git add server/src/server/zone/Sector.hx server/src/server/zone/SectorGrid.hx server/test/TestSectorGrid.hx server/test/TestMain.hx
git commit -m "$(cat <<'EOF'
feat(zone): sector grid spatial index

Pure SectorGrid + Sector with 8x8 cells, separate per-sector mobile and
item lists, Map<serial, Sector> membership for O(1) removal, and
sectorsInRange for AOI sweeps. ZoneSimulator integration + InterestManager
rewrite land in the next task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `ZoneSimulator` + `InterestManager` integration

This task wires the grid into the simulator, instruments the five
mutation sites + the inventory hooks, and rewrites `InterestManager` to
walk AOI sectors. No persistence change — the grid is rebuilt on boot
from existing DB load paths.

**Files:**
- Modify: `server/src/server/zone/ZoneSimulator.hx`
- Modify: `server/src/server/zone/InterestManager.hx`
- Modify: `server/src/server/zone/Main.hx`
- Modify: `server/test/TestInterestManager.hx`

- [ ] **Step 1: Add the grid to `ZoneSimulator`; delegate the lookups**

In `ZoneSimulator.hx`:

1. Add a `public var grid:SectorGrid` field, constructed in the
   constructor from `map.width` / `map.height`:

   ```haxe
   public var grid(default, null):SectorGrid;

   public function new(map, serials, zoneId, ...) {
     this.map = map;
     this.serials = serials;
     this.zoneId = zoneId;
     this.mobileDal = mobileDal;
     this.itemDal = itemDal;
     this.tileDal = tileDal;
     this.grid = new SectorGrid(map.width, map.height);
     scheduler.every(FLUSH_TICK_INTERVAL, flushMobilePositions);
   }
   ```

2. Replace `entityAt`, `itemAt`, `objectAt` with grid delegates:

   ```haxe
   public function entityAt(x:Int, y:Int):Null<Mobile> return grid.mobileAt(x, y);
   public function itemAt(x:Int, y:Int):Null<Item>     return grid.itemAt(x, y);
   public function objectAt(x:Int, y:Int):Bool         return grid.blockingItemAt(x, y);
   ```

   (The full-collection iterations these methods used to perform are gone.)

3. `canStep`, `worldObjects`, `groundItems` are unchanged in shape —
   `canStep` now hits `grid.mobileAt` + `grid.blockingItemAt`;
   `worldObjects` / `groundItems` still iterate `sim.items` (they're cold-
   path, only used by the zone-entry burst).

- [ ] **Step 2: Instrument the five mutation sites**

In `ZoneSimulator.hx`:

1. **`spawn(m)`** — add `grid.addMobile(m)` after `mobiles.set(...)`:

   ```haxe
   public function spawn(m:Mobile):Void {
     mobiles.set(m.serial, m);
     grid.addMobile(m);
     wireInventory(m);
   }
   ```

2. **`despawn(serial)`** — add `grid.removeMobile(serial)` before
   `mobiles.remove(...)`:

   ```haxe
   public function despawn(serial:Int):Void {
     grid.removeMobile(serial);
     mobiles.remove(serial);
   }
   ```

3. **`spawnItem(...)`** — add `grid.addItem(it)` after `items.set(...)`:

   ```haxe
   public function spawnItem(itemType:ItemType, count:Int, x:Int, y:Int):Item {
     var it = new Item(serials.nextItem(), itemType, count);
     it.tileX = x;
     it.tileY = y;
     items.set(it.serial, it);
     grid.addItem(it);
     pendingItemSpawns.push(it);
     ...
   }
   ```

4. **`attachWorldItem(it)`** — add `grid.addItem(it)`:

   ```haxe
   public function attachWorldItem(it:Item):Void {
     items.set(it.serial, it);
     grid.addItem(it);
   }
   ```

5. **Tile-step move in `tick()`** — add `grid.moveMobile(...)` after the
   `tileX/tileY` writes. The relevant block today is:

   ```haxe
       var fromX = m.tileX, fromY = m.tileY;
       m.tileX = nx;
       m.tileY = ny;
       m.nextMoveTick = currentTick + Constants.MOVE_TICKS;
   ```

   becomes:

   ```haxe
       var fromX = m.tileX, fromY = m.tileY;
       m.tileX = nx;
       m.tileY = ny;
       grid.moveMobile(m, fromX, fromY, nx, ny);
       m.nextMoveTick = currentTick + Constants.MOVE_TICKS;
   ```

   (`attachCarriedItem` does NOT touch the grid — carried items have no
   world position.)

- [ ] **Step 3: Update the inventory hooks for pickup/destroy**

In `ZoneSimulator.wireInventory`:

1. `onReparent` — fires on pickup (world → carried) and on slot reindex.
   The grid call is `grid.removeItem(it.serial)` — a no-op for the
   reindex case (item was never in the grid).

   ```haxe
   inv.onReparent = function(it:Item) {
     mp.set(it.serial, it);
     grid.removeItem(it.serial);
     if (idal != null) {
       try {
         idal.reparentToMobile(it.serial, m.serial, it.slot);
       } catch (err:Dynamic) {
         Sys.println('[zone] reparentToMobile failed for item ${it.serial}: $err');
       }
     }
   };
   ```

2. `onDestroy` — fires on merge-pickup and on removeCount-empties-slot.

   ```haxe
   inv.onDestroy = function(it:Item) {
     mp.remove(it.serial);
     grid.removeItem(it.serial);
     if (idal != null) {
       try {
         idal.delete(it.serial);
       } catch (err:Dynamic) {
         Sys.println('[zone] item delete failed for ${it.serial}: $err');
       }
     }
   };
   ```

   (`grid.removeItem` is a no-op when the item wasn't in the grid, so
   carried-item destruction is safe.)

`onAdd` and `onSlotCountChanged` do not touch the grid.

- [ ] **Step 4: Rewrite `InterestManager.update`**

Replace the body of `InterestManager.update` with a sector-walking
version. The full new file:

```haxe
package server.zone;

/**
 * Tracks, per observer mobile, the set of mobile serials that observer
 * currently knows about. Each tick `update` walks only the sectors
 * inside the observer's AOI (a square Chebyshev neighborhood of
 * DESPAWN_EXTENT tiles) rather than the full mobile list.
 *
 * Hysteresis: a mobile enters the known-set at distance <= SPAWN_EXTENT
 * and is dropped only past DESPAWN_EXTENT, so a mobile walking the AOI
 * boundary does not flicker.
 */
class InterestManager {
  public static inline var SPAWN_EXTENT = 32;
  public static inline var DESPAWN_EXTENT = 34;

  var known:Map<Int, Map<Int, Bool>> = new Map();

  public function new() {}

  /** Recompute interest for every mobile; return one diff per changed observer. */
  public function update(grid:SectorGrid, mobiles:Iterator<Mobile>):Array<InterestDiff> {
    var diffs:Array<InterestDiff> = [];
    for (obs in mobiles) {
      var prev = known.get(obs.serial);
      if (prev == null) prev = new Map();
      var nextSet = new Map<Int, Bool>();
      var entered:Array<Int> = [];
      var left:Array<Int> = [];

      for (sec in grid.sectorsInRange(obs.tileX, obs.tileY, DESPAWN_EXTENT)) {
        for (other in sec.mobiles) {
          if (other.serial == obs.serial) continue;
          var wasKnown = prev.exists(other.serial);
          var d = chebyshev(obs, other);
          var nowKnown = wasKnown ? (d <= DESPAWN_EXTENT) : (d <= SPAWN_EXTENT);
          if (nowKnown) {
            nextSet.set(other.serial, true);
            if (!wasKnown) entered.push(other.serial);
          }
        }
      }

      // Any previously-known mobile not in the new sweep has exited AOI.
      for (k in prev.keys()) {
        if (!nextSet.exists(k)) left.push(k);
      }

      known.set(obs.serial, nextSet);
      if (entered.length > 0 || left.length > 0) {
        diffs.push({ observerId: obs.serial, entered: entered, left: left });
      }
    }
    return diffs;
  }

  public function knows(observerId:Int, entityId:Int):Bool {
    if (observerId == entityId) return true;
    var s = known.get(observerId);
    return s != null && s.exists(entityId);
  }

  public function forget(entityId:Int):Array<Int> {
    var observersWhoKnew:Array<Int> = [];
    known.remove(entityId);
    for (obsId in known.keys()) {
      var s = known.get(obsId);
      if (s.exists(entityId)) {
        observersWhoKnew.push(obsId);
        s.remove(entityId);
      }
    }
    return observersWhoKnew;
  }

  public function observersOf(entityId:Int):Array<Int> {
    var out:Array<Int> = [];
    for (obsId in known.keys()) {
      if (obsId == entityId) continue;
      var s = known.get(obsId);
      if (s.exists(entityId)) out.push(obsId);
    }
    return out;
  }

  static inline function chebyshev(a:Mobile, b:Mobile):Int {
    var dx = a.tileX - b.tileX; if (dx < 0) dx = -dx;
    var dy = a.tileY - b.tileY; if (dy < 0) dy = -dy;
    return dx > dy ? dx : dy;
  }
}
```

- [ ] **Step 5: Update `Main.hx` to pass the grid into `update`**

In `server/src/server/zone/Main.hx`, replace the per-tick interest call:

```haxe
        var entityList = [for (m in sim.allMobiles()) m];
        broadcastInterestDiffs(sim, interest.update(entityList));
```

with:

```haxe
        broadcastInterestDiffs(sim, interest.update(sim.grid, sim.allMobiles()));
```

(The `entityList` array materialization is no longer needed — the
interest manager takes the iterator directly.)

- [ ] **Step 6: Update `TestInterestManager`**

The existing tests call `im.update([a, b, ...])`. They now need a grid
and the mobiles must be registered in it. Rewrite each test to build a
`SectorGrid`, register the mobiles, and pass the grid to `update`. The
existing assertions carry over.

Replace `TestInterestManager.hx` with:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Mobile;
import server.zone.SectorGrid;
import server.zone.InterestManager;
import server.zone.InterestDiff;

class TestInterestManager extends Test {
  static function mob(serial:Int, x:Int, y:Int):Mobile {
    return new Mobile(serial, 'm$serial', null, x, y);
  }

  static function diffFor(diffs:Array<InterestDiff>, observerId:Int):Null<InterestDiff> {
    for (d in diffs) if (d.observerId == observerId) return d;
    return null;
  }

  /** Move a mobile in the grid and update its tile fields together. */
  static function moveTo(grid:SectorGrid, m:Mobile, x:Int, y:Int):Void {
    grid.moveMobile(m, m.tileX, m.tileY, x, y);
    m.tileX = x; m.tileY = y;
  }

  /** Build a grid, register the mobiles, return both. */
  static function setup(mobiles:Array<Mobile>):{ grid:SectorGrid, list:Array<Mobile> } {
    var g = new SectorGrid(1024, 1024);
    for (m in mobiles) g.addMobile(m);
    return { grid: g, list: mobiles };
  }

  function testFarApartNeverKnown() {
    var s = setup([mob(1, 0, 0), mob(2, 200, 0)]);
    var diffs = new InterestManager().update(s.grid, s.list.iterator());
    Assert.equals(0, diffs.length);
  }

  function testEnterRangeProducesDiff() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 200, 0);
    var s = setup([a, b]);
    im.update(s.grid, s.list.iterator());
    moveTo(s.grid, b, 20, 0);
    var diffs = im.update(s.grid, s.list.iterator());
    var da = diffFor(diffs, 1);
    Assert.notNull(da);
    Assert.isTrue(da.entered.indexOf(2) >= 0);
    Assert.isTrue(im.knows(1, 2));
  }

  function testLeaveRangePastHysteresis() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 10, 0);
    var s = setup([a, b]);
    im.update(s.grid, s.list.iterator());
    moveTo(s.grid, b, 33, 0);
    var d1 = im.update(s.grid, s.list.iterator());
    Assert.isNull(diffFor(d1, 1));
    moveTo(s.grid, b, 40, 0);
    var d2 = im.update(s.grid, s.list.iterator());
    var da = diffFor(d2, 1);
    Assert.notNull(da);
    Assert.isTrue(da.left.indexOf(2) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }

  function testHysteresisBandDoesNotEnter() {
    var s = setup([mob(1, 0, 0), mob(2, 33, 0)]);
    var diffs = new InterestManager().update(s.grid, s.list.iterator());
    Assert.equals(0, diffs.length);
  }

  function testSelfAlwaysKnown() {
    Assert.isTrue(new InterestManager().knows(1, 1));
  }

  function testForgetReturnsObserversAndClears() {
    var im = new InterestManager();
    var s = setup([mob(1, 0, 0), mob(2, 10, 0)]);
    im.update(s.grid, s.list.iterator());
    var observers = im.forget(2);
    Assert.isTrue(observers.indexOf(1) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }

  function testObserversOfReturnsKnowers() {
    var im = new InterestManager();
    var s = setup([mob(1, 0, 0), mob(2, 10, 0), mob(3, 500, 0)]);
    im.update(s.grid, s.list.iterator());
    var obs = im.observersOf(1);
    Assert.isTrue(obs.indexOf(2) >= 0);
    Assert.isFalse(obs.indexOf(3) >= 0);
    Assert.isFalse(obs.indexOf(1) >= 0);
  }

  function testIsolatedPairsDoNotCross() {
    var im = new InterestManager();
    var a = mob(1, 100, 100);
    var b = mob(2, 105, 100);    // within range of a
    var c = mob(3, 800, 800);
    var d = mob(4, 805, 800);    // within range of c
    var s = setup([a, b, c, d]);
    var diffs = im.update(s.grid, s.list.iterator());
    var da = diffFor(diffs, 1);
    Assert.notNull(da);
    Assert.isTrue(da.entered.indexOf(2) >= 0);   // a sees b
    Assert.isFalse(da.entered.indexOf(3) >= 0);  // a does NOT see c
    Assert.isFalse(da.entered.indexOf(4) >= 0);  // a does NOT see d
  }
}
```

- [ ] **Step 7: Build everything**

Run: `./build_native.sh shared-test client-test server-test zone gateway client`
Expected: all targets compile.

- [ ] **Step 8: Run the unit suites**

Run: `./bin/shared-test && ./bin/client-test`
Expected: both `ALL TESTS OK`. Then `./bin/server-test` — `TestSectorGrid`,
`TestInterestManager`, `TestZoneSimulator`, `TestWorldPopulator`,
`TestCrafting`, `TestTileInteraction`, `TestInventory`, `TestItem`,
`TestZoneBoot`, `TestSerials`, `TestScheduler` all green; only the
live-server integration cases error (verified next).

- [ ] **Step 9: Run the integration suite**

```bash
pkill -f 'bin/zone' ; pkill -f 'bin/gateway' ; sleep 1
./run-integration.sh
```

Expected: `ALL TESTS OK` (502/502 or higher with the new unit cases).
`TestZoneLifecycle` (walk + pick up + logout + reconnect),
`TestZoneInterest` (two-client spawn + move filtering),
`TestZoneChat` (interest-bounded chat) all exercise the new grid paths.

- [ ] **Step 10: Commit**

```bash
git add server/src/server/zone/ZoneSimulator.hx server/src/server/zone/InterestManager.hx server/src/server/zone/Main.hx server/test/TestInterestManager.hx
git commit -m "$(cat <<'EOF'
feat(zone): wire the sector grid into ZoneSimulator + InterestManager

entityAt / itemAt / objectAt now delegate to SectorGrid, eliminating the
linear scan of mobiles + items on every lookup. The five world-position
mutation sites (spawn, despawn, spawnItem, attachWorldItem, tick-step
move) re-key the grid; inventory hooks (onReparent, onDestroy) remove
items from the grid on pickup/destroy.

InterestManager.update now walks only the AOI sector neighborhood around
each observer instead of every mobile; the per-tick interest cost drops
from O(n^2) to O(n * sector_AOI * avg_per_sector).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:**

- §1 *SectorGrid + Sector* — class shape, two-array per-sector storage,
  membership maps, `sectorsInRange` with sector-radius rounding → Task 1.
- §2 *ZoneSimulator integration* — grid field, three delegate lookups,
  five mutation-site instrumentations, two inventory-hook updates → Task 2
  Steps 1–3.
- §3 *InterestManager rewrite* — sector-walking `update` signature,
  `prev \ nextSet` for `left` computation, unchanged `knows`/`forget`/
  `observersOf` → Task 2 Step 4.
- §4 *Edge cases* — sector boundary (covered by `testMobileMoveAcrossSectorBoundary`),
  same-tile mobile+item (`testSameTileMobileAndItem`), same-sector move
  short-circuit (verified by `moveMobile`'s fromKey/toKey check),
  off-map lookup (`testMobileAtOffMapReturnsNull`), pickup → grid.removeItem,
  load via `attachWorldItem` → grid.addItem.
- §5 *Testing* — `TestSectorGrid` (Task 1 Step 1) + `TestInterestManager`
  rewrites (Task 2 Step 6) + integration regression (Task 2 Steps 8–9).

**Risks mitigation:**

- *Move-site coverage* — the five sites are named in Task 2 Step 2; the
  integration suite walks + picks up + crafts + places furniture, which
  hits all five.
- *Inventory-hook side effects* — Task 2 Step 3 adds `grid.removeItem`
  to both `onReparent` and `onDestroy`; `grid.removeItem` is a no-op
  when the serial isn't in `itemLoc`, so the reindex case is safe.
- *InterestManager `left` set* — at the current tick rate and move speed
  (1 tile per MOVE_TICKS), a mobile in AOI last tick is still well
  within the DESPAWN_EXTENT sector window this tick. The
  `testLeaveRangePastHysteresis` case exercises this.
- *Hardcoded SECTOR_SIZE* — declared as `static inline var` so the
  compiler folds it. If tuning becomes necessary later, promotes to a
  constructor arg with low blast radius.

**Placeholder scan:** none — every step has concrete code or an exact
command.

**Type consistency:** `SectorGrid` field types
(`widthSectors:Int`, `heightSectors:Int`, `sectors:Array<Sector>`,
`mobileLoc:Map<Int, Sector>`, `itemLoc:Map<Int, Sector>`) match their
uses across `addMobile`/`moveMobile`/`removeMobile`/`addItem`/`removeItem`/
`mobileAt`/`itemAt`/`blockingItemAt`/`sectorsInRange`. `InterestManager.update`
signature `(SectorGrid, Iterator<Mobile>) -> Array<InterestDiff>` matches
the new `Main.hx` call site and the test usage.

**Out of scope:** turning `growTiles` into a sector-driven scan
(operates on tiles, not entities); spatial indices for tile overrides
(already keyed by `(x,y)` in the DAL); cross-zone visibility; lazy
sector allocation (eager array is cheap at the current scale).
