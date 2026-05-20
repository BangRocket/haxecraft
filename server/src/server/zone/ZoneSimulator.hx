package server.zone;

import shared.Constants;
import shared.world.MapData;
import shared.world.Direction;
import shared.world.TileType;
import shared.item.ItemType;

/** A tile step applied during a tick; the caller turns these into MsgEntityMove. */
typedef MoveResult = { entityId:Int, fromX:Int, fromY:Int, toX:Int, toY:Int };

/** An item picked up during a tick; the caller broadcasts the despawn + inventory. */
typedef PickupResult = { entity:Mobile, worldItemSerial:Int };

class ZoneSimulator {
  public var currentTick(default, null):Int = 0;
  public var map(default, null):MapData;
  public var zoneId(default, null):Int;

  /** Serial allocator (mobile + item ranges). */
  public var serials(default, null):Serials;

  /** Tick scheduler — drives the DB flush and (later) combat/respawn timers. */
  public var scheduler(default, null):Scheduler = new Scheduler();

  /** Spatial index over world-placed entities. Tile lookups + AOI sweeps
      go through here; the keyed-by-serial maps below are still authoritative
      for "give me every mobile" iteration. */
  public var grid(default, null):SectorGrid;

  /** Live mobiles, keyed by serial. */
  public var mobiles(default, null):Map<Int, Mobile> = new Map();
  /** Live items (both world-placed and carried), keyed by serial. */
  public var items(default, null):Map<Int, Item> = new Map();

  public static inline var FLUSH_TICK_INTERVAL:Int = 50;  // 5s at 10 Hz

  public var movesThisTick(default, null):Array<MoveResult> = [];
  public var pickupsThisTick(default, null):Array<PickupResult> = [];

  /** Tile changes + item spawns since the last flush (interaction + growth). */
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
    this.grid = new SectorGrid(map.width, map.height);
    scheduler.every(FLUSH_TICK_INTERVAL, flushMobilePositions);
  }

  public function flushMobilePositions():Void {
    if (mobileDal == null) return;
    for (m in mobiles) {
      try {
        mobileDal.savePosition(m.serial, m.tileX, m.tileY);
        mobileDal.saveStatsAndHp(m.serial, m.str, m.dex, m.intel, m.hp, m.maxHp);
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
      grid.moveMobile(m, fromX, fromY, nx, ny);
      m.nextMoveTick = currentTick + Constants.MOVE_TICKS;
      movesThisTick.push({ entityId: m.serial, fromX: fromX, fromY: fromY, toX: nx, toY: ny });

      // SP3: walking onto a non-blocking ground item picks it up.
      var gi = itemAt(nx, ny);
      if (gi != null && !gi.blocksMovement()) {
        m.inventory.addExisting(gi);   // hooks handle items map + DAL
        pickupsThisTick.push({ entity: m, worldItemSerial: gi.serial });
      }
    }
    growTiles();
    scheduler.tick();
  }

  /** Advance growth on tiles near connected players (bounded scan). */
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
      a serial, inserts the row, queues the spawn broadcast, returns the Item. */
  public function spawnItem(itemType:ItemType, count:Int, x:Int, y:Int):Item {
    var it = new Item(serials.nextItem(), itemType, count);
    it.tileX = x;
    it.tileY = y;
    items.set(it.serial, it);
    grid.addItem(it);
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

  /** Mutate a tile's type + data, record a change for broadcast, and
      persist the edit so it survives a zone restart. */
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
  public function itemAt(x:Int, y:Int):Null<Item> return grid.itemAt(x, y);

  public function spawn(m:Mobile):Void {
    mobiles.set(m.serial, m);
    grid.addMobile(m);
    wireInventory(m);
  }

  public function despawn(serial:Int):Void {
    grid.removeMobile(serial);
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

  public function entityAt(x:Int, y:Int):Null<Mobile> return grid.mobileAt(x, y);

  /** True if a blocking item (placed furniture) sits on (x, y). */
  public function objectAt(x:Int, y:Int):Bool return grid.blockingItemAt(x, y);

  /** Iterate world-placed blocking items (placed furniture). */
  public function worldObjects():Iterator<Item> {
    var arr:Array<Item> = [];
    for (it in items) if (it.inWorld() && it.blocksMovement()) arr.push(it);
    return arr.iterator();
  }

  /** Iterate world-placed non-blocking items (ground items). */
  public function groundItems():Iterator<Item> {
    var arr:Array<Item> = [];
    for (it in items) if (it.inWorld() && !it.blocksMovement()) arr.push(it);
    return arr.iterator();
  }

  /** Unified walkability: walkable terrain, no mobile, no blocking item. */
  public function canStep(x:Int, y:Int):Bool {
    return map.isWalkable(x, y) && entityAt(x, y) == null && !objectAt(x, y);
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
    grid.addItem(it);
  }

  /** Install persistence hooks on a mobile's inventory. */
  function wireInventory(m:Mobile):Void {
    var inv = m.inventory;
    var idal = itemDal;
    var mp = items;
    var g = grid;
    inv.onAdd = function(it:Item) {
      mp.set(it.serial, it);
      if (idal != null) {
        try {
          idal.insertCarried(it.serial, (it.itemType : Int), it.count, m.serial, it.slot);
        } catch (err:Dynamic) {
          Sys.println('[zone] insertCarried failed for item ${it.serial}: $err');
        }
      }
    };
    inv.onReparent = function(it:Item) {
      mp.set(it.serial, it);
      // Pickup case: the item just moved world -> carried. Deregister
      // from the grid so itemAt no longer returns it. Reindex case (slot
      // shift after removeCount): no-op since the item was never on the grid.
      g.removeItem(it.serial);
      if (idal != null) {
        try {
          idal.reparentToMobile(it.serial, m.serial, it.slot);
        } catch (err:Dynamic) {
          Sys.println('[zone] reparentToMobile failed for item ${it.serial}: $err');
        }
      }
    };
    inv.onSlotCountChanged = function(it:Item) {
      if (idal != null) {
        try {
          idal.updateCount(it.serial, it.count);
        } catch (err:Dynamic) {
          Sys.println('[zone] updateCount failed for item ${it.serial}: $err');
        }
      }
    };
    inv.onDestroy = function(it:Item) {
      mp.remove(it.serial);
      g.removeItem(it.serial);
      if (idal != null) {
        try {
          idal.delete(it.serial);
        } catch (err:Dynamic) {
          Sys.println('[zone] item delete failed for ${it.serial}: $err');
        }
      }
    };
  }
}
