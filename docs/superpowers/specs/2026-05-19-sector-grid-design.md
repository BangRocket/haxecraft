# Sector Grid (Spatial Index) — Design

**Date:** 2026-05-19
**Status:** Approved (design); pending implementation plan

## Context

The UO-patterns arc, sub-project 3 of 3 (final):

1. Tick scheduler (timers) — *done; merged in `ad1d2c2`*
2. Unified `Mobile` / `Item` entity model + serials — *done; merged in `0806d84`*
3. **Sector grid (spatial index)** ← *this spec*

Arc 2 unified mobiles and items behind a single `serial` and put them in two
keyed-by-serial maps inside `ZoneSimulator`. Every spatial query —
`entityAt(x,y)`, `itemAt(x,y)`, `objectAt(x,y)`, the `canStep` walk-check,
`worldObjects()`/`groundItems()` iteration — and every interest-management
tick still pays an O(n) (or O(n²) for interest) scan over the full
collection. That's tolerable at the current scale (a handful of mobiles, a
few dozen items) but is on the critical path of every move tick and grows
linearly with population.

UO's solution is the *sector*: divide the map into fixed-size square tiles
of tiles, keep a per-sector list of the entities inside it. Every tile
lookup becomes O(sector occupants); every AOI sweep walks only the sectors
inside the radius. We adopt that shape.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Index scope | One combined grid holding both mobiles and world-placed items |
| Sector size | 8×8 tiles |
| InterestManager migration | Yes — rewrite to scan AOI sectors instead of every mobile |
| Sector allocation | Eager 2D array — predictable cost, simple math |
| Per-entity sector tracking | Internal `Map<Int, Sector>` (by serial) inside `SectorGrid` |
| Carried items | Excluded — they have no world position |

**Why 8×8.** The starter map is 1024×1024, so an 8×8 sector size yields a
128×128 sector grid (16,384 sectors). At 8 bytes per Sector pointer that
is ~128 KB — negligible. The AOI is bounded by `DESPAWN_EXTENT = 34`, so
the worst-case AOI in sector units is `ceil(34/8) = 5` → an 11×11 = 121
sector neighborhood per observer. With a few entities per sector, the
per-tick interest cost is ~hundreds of comparisons, not the current
n×(n−1) sweep. A 16×16 sector size would halve the neighborhood (5×5 = 25
sectors) but each sector covers 4× the tiles, so per-sector occupancy
rises proportionally; 8×8 trades a slightly wider sweep for cheaper
per-tile lookups, which we do more often than AOI sweeps.

## Scope

**In scope:** a `SectorGrid` class keyed by sector coordinates; per-sector
lists of `Mobile` + `Item`; `ZoneSimulator` integration (replace the
linear scans in `entityAt`, `itemAt`, `objectAt`, `canStep`, `worldObjects`,
`groundItems` with sector-bounded scans; instrument move / spawn / despawn
/ pickup / drop to maintain the grid); `InterestManager` rewrite to scan
AOI sectors.

**Out of scope:** turning `growTiles` into a sector- or interest-driven
scan (it operates on tiles, not entities, and the per-tile work is the
unavoidable cost); spatial indices for tile-overrides (already keyed by
`(x,y)` in the DAL); cross-zone visibility; future R-tree / quad-tree
variants. Persistence does not change — the grid is rebuilt in-memory on
boot from the existing DB load paths.

## Section 1 — `SectorGrid` and `Sector`

Two new files in `server.zone`, both pure (no I/O):

**`server/src/server/zone/Sector.hx`** — a single grid cell:

```haxe
class Sector {
  public var sx:Int;
  public var sy:Int;
  public var mobiles:Array<Mobile> = [];
  public var items:Array<Item> = [];
  public function new(sx:Int, sy:Int) { this.sx = sx; this.sy = sy; }
}
```

Two arrays per sector — one per kind — so kind-specific iteration
(`itemAt`, `entityAt`) doesn't scan the other kind. Both arrays are
typically small (1-5 entries).

**`server/src/server/zone/SectorGrid.hx`** — the grid:

```haxe
class SectorGrid {
  public static inline var SECTOR_SIZE:Int = 8;

  public var widthSectors(default, null):Int;
  public var heightSectors(default, null):Int;
  var sectors:Array<Sector>;                  // row-major, length w*h
  var mobileLoc:Map<Int, Sector> = new Map(); // serial -> current sector
  var itemLoc:Map<Int, Sector> = new Map();

  public function new(mapWidthTiles:Int, mapHeightTiles:Int) { ... }

  // Mobile + item add/move/remove.
  public function addMobile(m:Mobile):Void;
  public function moveMobile(m:Mobile, fromX:Int, fromY:Int, toX:Int, toY:Int):Void;
  public function removeMobile(serial:Int):Void;

  public function addItem(it:Item):Void;        // requires it.inWorld()
  public function removeItem(serial:Int):Void;  // call on pickup or destroy
  // Note: items don't tile-step (they teleport on spawn/drop/pickup), so
  // there is no moveItem — pickup is remove+addCarrying-to-inventory; a
  // drop is remove (it's gone from the carrying inventory) + add to grid.

  // Tile-precise lookups (scans one sector).
  public function mobileAt(x:Int, y:Int):Null<Mobile>;
  public function itemAt(x:Int, y:Int):Null<Item>;
  public function blockingItemAt(x:Int, y:Int):Bool;

  // Iteration over a sector neighborhood (used by InterestManager).
  public function sectorsInRange(centerX:Int, centerY:Int, tileRadius:Int):Iterator<Sector>;
}
```

`sectorsInRange` translates a tile radius to a sector radius
(`ceil(tileRadius / SECTOR_SIZE)`) and yields the sectors in the bounded
neighborhood. The caller filters individual entities by exact tile
distance (the sector ceiling overestimates).

**Why a `Map<serial, Sector>` instead of a per-entity `currentSector`
field on `Mobile`/`Item`?** It keeps the grid self-contained — adding a
field to `Mobile`/`Item` couples those classes to spatial indexing and
makes serialization paths (the DB load helpers) more complex. The map is
also strictly necessary for fast removal (`removeMobile(serial)` without
knowing the entity's current position).

**Why eager allocation?** A 1024×1024 map is 16K sectors × ~8 bytes per
pointer = 128 KB, negligible. Eager fixed-array indexing is `O(1)` with
no rehashing or empty-bucket allocation cost.

## Section 2 — `ZoneSimulator` integration

The simulator gains a `SectorGrid` field; the existing tile-lookup helpers
become thin delegates:

```haxe
public var grid(default, null):SectorGrid;

public function new(map, serials, zoneId, ...) {
  ...
  this.grid = new SectorGrid(map.width, map.height);
}

public function entityAt(x:Int, y:Int):Null<Mobile> return grid.mobileAt(x, y);
public function itemAt(x:Int, y:Int):Null<Item>   return grid.itemAt(x, y);
public function objectAt(x:Int, y:Int):Bool       return grid.blockingItemAt(x, y);
```

**Mutation sites:** every place that writes a world position calls into
the grid. There are five:

1. **`spawn(m)`** — `grid.addMobile(m)` after `mobiles.set(...)`.
2. **`despawn(serial)`** — `grid.removeMobile(serial)` before `mobiles.remove(...)`.
3. **`spawnItem(...)`** — `grid.addItem(it)` after `items.set(...)`.
4. **`attachWorldItem(it)`** — same as `spawnItem` minus the DAL insert
   (the load path). `grid.addItem(it)`.
5. **`tick()` step move** — when a mobile actually steps,
   `grid.moveMobile(m, fromX, fromY, nx, ny)` immediately after the
   `m.tileX = nx; m.tileY = ny;` writes.

For inventory hooks (installed in `wireInventory`):
- `onReparent` — fires on pickup or slot reindex. **Pickup case**: the
  item transitions from world to carried. The hook calls
  `grid.removeItem(it.serial)` so subsequent `itemAt` scans don't find
  it. **Reindex case**: the item was already carried (parent unchanged);
  `removeItem` is a no-op (the grid never knew about it).
- `onDestroy` — fires on merge-pickup or removeCount-empties-slot.
  `grid.removeItem(it.serial)` is also called (no-op for already-carried
  items).
- `onAdd` and `onSlotCountChanged` — no grid changes (the carried slot's
  position is its parent's, not a world tile).

**Drop path** (for the future `dropItem` action and crafting-place):
adding a world item via `spawnItem` already covers it — placing furniture
calls `spawnItem`, which registers in the grid.

**`worldObjects()` and `groundItems()` iterators** stay on the simulator
but iterate the grid's tracking maps (filtering by blocking) rather than
the full `items` map. Even simpler: keep them as-is (they iterate
`items`, an existing `Map<serial, Item>`) — they're not hot-path code
(only the zone-entry burst uses them).

## Section 3 — `InterestManager` rewrite

Today `InterestManager.update(mobiles)` is O(n²): for each observer, walk
every other mobile and compute Chebyshev distance. With the grid, each
observer walks only the sectors in its AOI:

```haxe
public function update(grid:SectorGrid, mobiles:Iterator<Mobile>):Array<InterestDiff> {
  var diffs:Array<InterestDiff> = [];
  for (obs in mobiles) {
    var prev = known.get(obs.serial); if (prev == null) prev = new Map();
    var nextSet = new Map<Int, Bool>();
    var entered:Array<Int> = [];
    var left:Array<Int> = [];

    // Walk only sectors within DESPAWN_EXTENT of the observer.
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

    // Compute `left` from prev \ nextSet (an observer's previously-known
    // mobile that's no longer in any nearby sector exits AOI).
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
```

Two structural changes from today's loop:

- The inner loop iterates only nearby sectors, not the full mobile
  collection. Complexity is `O(observers × sector_AOI × avg_mobiles_per_sector)`
  ≈ `O(n × 121 × ~1)` for the starter zone — well below the current
  `O(n²)`.
- The "departed" set is computed by *diffing the previous known-set
  against the current sweep* rather than by per-pair distance check
  (since the new sweep doesn't visit all previously-known mobiles —
  they may now be outside the AOI sector window). The hysteresis
  semantics are preserved: any mobile not in `nextSet` is treated as
  having left.

`knows`, `forget`, and `observersOf` are unchanged — they read the
`known` map directly.

## Section 4 — Edge cases

- **Spawn on a sector boundary.** Sector indexing is `(x >> 3, y >> 3)`
  (since SECTOR_SIZE = 8). A tile at x=7 lives in sector (0,0); x=8 in
  (1,0). Standard floor-division; the move from x=7 to x=8 always
  triggers `moveMobile` which re-keys.
- **Same-tile mobile + item.** The grid stores them in separate arrays
  on the same sector. `mobileAt` and `itemAt` scan different arrays —
  no cross-kind matches.
- **Move that doesn't change sector.** `moveMobile` short-circuits when
  `(fromX >> 3, fromY >> 3) == (toX >> 3, toY >> 3)` — no array
  manipulation needed.
- **Move to a sector that doesn't exist yet (off-map).** Off-map positions
  are blocked upstream by `map.isWalkable`. The grid still bounds-checks
  to be defensive: `mobileAt(-1, 0)` returns null.
- **Pickup of a stack-merging item.** The incoming item's `onDestroy`
  fires → `grid.removeItem(it.serial)` — no-op since this item is the
  one being merged-into-existing-slot, not the surviving one. Correct
  behavior is "do nothing further; the surviving stack stays in the
  carrying inventory."
- **Load on boot.** `attachWorldItem` registers each loaded item via
  `grid.addItem`. `attachCarriedItem` does *not* — carried items have no
  world position. The bootstrap order in `Main.hx` (DB load → simulator
  attach → grid.add) is preserved.

## Section 5 — Testing

**Unit — `server/test/TestSectorGrid.hx`:**

- `addMobile` then `mobileAt(x,y)` returns it; `mobileAt` at a different
  tile returns null.
- `addItem` for furniture → `blockingItemAt(x,y)` true; for a resource →
  false.
- `moveMobile` updates the grid: after move, `mobileAt(oldX, oldY)` is
  null and `mobileAt(newX, newY)` returns the mobile.
- `removeMobile(serial)` removes from grid; subsequent `mobileAt` at the
  former position returns null.
- `sectorsInRange(centerX, centerY, radius)` covers the correct sector
  rectangle (no missing edge sectors when the radius doesn't divide
  evenly by 8).
- Move across a sector boundary: same lookup behavior as same-sector
  move; the entity ends up in the new sector's lists, not in both.
- A mobile and an item on the same tile: both lookups find their own kind.

**Unit — `server/test/TestInterestManager.hx` (updated):**

The existing assertions (hysteresis, far-apart-never-known, etc.) carry
over. Add:
- A 4-mobile scene where two pairs are inside their own AOI but the
  pairs are far apart — assert no cross-pair entered events.
- A many-mobile scene (10+) that exercises the sector-walk path with
  measurable AOI sweep.

**Integration:** `TestZoneLifecycle`, `TestZoneInterest`, `TestZoneChat`
are unchanged. Their passing confirms the grid integrates correctly with
the existing simulator and that interest broadcasts arrive as expected.

**Regression:** the full unit + integration suite remains green.

## Section 6 — Risks

- **Move-site coverage.** Missing one of the five mutation sites means
  the grid drifts out of sync with the actual entity positions. The plan
  pins the five sites by name; the integration suite (which walks +
  picks up + crafts + places furniture) exercises all of them.
- **Inventory-hook side effects.** Calling `grid.removeItem` from
  `onReparent` and `onDestroy` is necessary for the pickup→carried
  transition. For the *reindex* case of `onReparent` (slot order change
  after a removeCount), `removeItem` is a no-op — the item was never
  in the grid. The plan asserts both paths with a dedicated test.
- **InterestManager `left` set.** Computing departures as
  `prev \ nextSet` is correct only if the new sweep visits every
  previously-known mobile that's *still in range*. The DESPAWN_EXTENT
  sector radius ensures this — a mobile that was in AOI last tick can
  have moved at most a few tiles, so it's still within the DESPAWN
  sector window. (At our tick rate and movement speed, a one-tick move
  is bounded by 1 tile.)
- **Sector size as a magic constant.** `SECTOR_SIZE = 8` is hardcoded
  for now. If a future zone needs a different tuning (e.g. a tiny
  arena), the constant promotes cleanly to a constructor arg.

## Sub-project boundary

Complete when: `SectorGrid` and `Sector` exist and are unit-tested; the
simulator's tile-lookup helpers delegate to the grid; every move/spawn/
despawn/pickup site updates the grid; `InterestManager.update` walks AOI
sectors rather than the full mobile list; the full unit + integration
suite is green.

This is the final sub-project of the UO-patterns arc. After it merges,
the haxecraft zone has the three load-bearing ModernUO patterns in
place: tick-driven scheduling, unified serialized entities, and a
sector-based spatial index. M3 (combat/skills/death) is now unblocked
on infrastructure.
