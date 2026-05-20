package server.zone;

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

  /** Re-key a mobile that just moved from (fromX,fromY) to (toX,toY). */
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
