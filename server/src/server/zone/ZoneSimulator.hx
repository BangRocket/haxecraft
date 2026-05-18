package server.zone;

import shared.Constants;
import shared.world.MapData;
import shared.world.Direction;
import shared.world.TileType;
import shared.item.ItemType;

/** A tile step applied during a tick; the caller turns these into MsgEntityMove. */
typedef MoveResult = { entityId:Int, fromX:Int, fromY:Int, toX:Int, toY:Int };

/** A ground item picked up during a tick; the caller despawns + resyncs. */
typedef PickupResult = { entity:Character, worldItemId:Int };

class ZoneSimulator {
  public var currentTick(default, null):Int = 0;
  public var map(default, null):MapData;
  var entities:Map<Int, Character> = new Map();

  public var lastFlushTick:Int = 0;
  public static inline var FLUSH_TICK_INTERVAL:Int = 50;  // 5s at 10 Hz

  /** Moves applied by the most recent tick(). The zone loop broadcasts these. */
  public var movesThisTick(default, null):Array<MoveResult> = [];

  /** Static world content (SP2). Ground items never block; objects do. */
  public var groundItems(default, null):Array<GroundItem> = [];
  public var worldObjects(default, null):Array<WorldObject> = [];

  /** Items picked up by the most recent tick(). The zone loop broadcasts these. */
  public var pickupsThisTick(default, null):Array<PickupResult> = [];

  /** Tile changes + item spawns since the last flush (interaction + growth). */
  public var pendingTileChanges(default, null):Array<{x:Int, y:Int, type:Int, data:Int}> = [];
  public var pendingItemSpawns(default, null):Array<GroundItem> = [];

  var nextGroundItemId:Int = 1;
  var nextObjectId:Int = 1;

  var characterDal:server.db.CharacterDal;
  var tileDal:server.db.ZoneTileDal;

  public function new(map:MapData, ?characterDal:server.db.CharacterDal,
      ?tileDal:server.db.ZoneTileDal) {
    this.map = map;
    this.characterDal = characterDal;
    this.tileDal = tileDal;
  }

  public function shouldFlushNow():Bool {
    return (currentTick - lastFlushTick) >= FLUSH_TICK_INTERVAL;
  }

  public function markFlushed():Void {
    lastFlushTick = currentTick;
  }

  public function flushPositions():Void {
    if (characterDal == null) return;
    for (e in entities) {
      characterDal.savePosition(e.id, e.tileX, e.tileY);
      characterDal.saveInventory(e.id, e.inventory.toRows());
    }
    markFlushed();
  }

  public function tick():Void {
    currentTick++;
    movesThisTick = [];
    pickupsThisTick = [];
    // Apply each entity's queued move once its per-step cooldown has elapsed.
    // Intents that arrive mid-cooldown stay queued (not dropped), so a held
    // direction steps on an exact, steady cadence instead of stuttering.
    for (e in entities) {
      if (e.pendingDir < 0) continue;
      if (currentTick < e.nextMoveTick) continue;  // cooldown — keep the intent

      var dir:Direction = cast e.pendingDir;
      e.pendingDir = -1;  // consume

      var dx = dir.dx();
      var dy = dir.dy();
      if (dx == 0 && dy == 0) continue;

      var nx = e.tileX + dx;
      var ny = e.tileY + dy;
      if (!canStep(nx, ny)) continue;

      var fromX = e.tileX, fromY = e.tileY;
      e.tileX = nx;
      e.tileY = ny;
      e.nextMoveTick = currentTick + Constants.MOVE_TICKS;
      movesThisTick.push({ entityId: e.id, fromX: fromX, fromY: fromY, toX: nx, toY: ny });

      // SP3: walking onto a ground item picks it up.
      var gi = groundItemAt(nx, ny);
      if (gi != null) {
        e.inventory.add(gi.itemType, gi.count);
        groundItems.remove(gi);
        pickupsThisTick.push({ entity: e, worldItemId: gi.id });
      }
    }
    growTiles();
  }

  /** Advance growth on tiles near connected players (bounded scan). */
  function growTiles():Void {
    var seen = new Map<Int, Bool>();
    for (e in entities) {
      for (ty in (e.tileY - 16)...(e.tileY + 17)) {
        for (tx in (e.tileX - 16)...(e.tileX + 17)) {
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
        // Broadcast only at the visual growth stages to limit wire traffic.
        if (nd == 10 || nd == 20 || nd == 30 || nd == 40 || nd == 50) {
          pendingTileChanges.push({ x: x, y: y, type: t, data: nd });
        }
      }
    }
  }

  public function freshGroundItemId():Int return nextGroundItemId++;
  public function freshObjectId():Int return nextObjectId++;

  /** Create a ground item with a fresh id; records it for spawn broadcast. */
  public function spawnGroundItem(itemType:ItemType, count:Int, x:Int, y:Int):GroundItem {
    var gi = new GroundItem(nextGroundItemId++, itemType, count, x, y);
    groundItems.push(gi);
    pendingItemSpawns.push(gi);
    return gi;
  }

  /** Mutate a tile's type + data, record a change for broadcast, and
      persist the edit so it survives a zone restart. */
  public function changeTile(x:Int, y:Int, type:TileType, data:Int):Void {
    map.setTile(x, y, type);
    map.setTileData(x, y, data);
    pendingTileChanges.push({ x: x, y: y, type: (type : Int), data: data });
    if (tileDal != null) tileDal.upsert(x, y, (type : Int), data);
  }

  /** Clear the pending tile/item event lists (after the zone loop flushes them). */
  public function clearPending():Void {
    pendingTileChanges = [];
    pendingItemSpawns = [];
  }

  /** The ground item on (x, y), or null. */
  public function groundItemAt(x:Int, y:Int):Null<GroundItem> {
    for (g in groundItems) {
      if (g.tileX == x && g.tileY == y) return g;
    }
    return null;
  }

  public function spawn(ch:Character):Void {
    entities.set(ch.id, ch);
  }

  public function despawn(id:Int):Void {
    entities.remove(id);
  }

  public function entityById(id:Int):Null<Character> {
    return entities.get(id);
  }

  public function entityCount():Int {
    var n = 0;
    for (_ in entities) n++;
    return n;
  }

  public function allEntities():Iterator<Character> {
    return entities.iterator();
  }

  public function entityAt(x:Int, y:Int):Null<Character> {
    for (e in entities) {
      if (e.tileX == x && e.tileY == y) return e;
    }
    return null;
  }

  public function addGroundItem(gi:GroundItem):Void {
    groundItems.push(gi);
  }

  public function addWorldObject(wo:WorldObject):Void {
    worldObjects.push(wo);
  }

  /** True if a world object occupies (x, y). */
  public function objectAt(x:Int, y:Int):Bool {
    for (o in worldObjects) {
      if (o.tileX == x && o.tileY == y) return true;
    }
    return false;
  }

  /** Unified walkability: walkable terrain, no player, no world object.
      Ground items never block. */
  public function canStep(x:Int, y:Int):Bool {
    return map.isWalkable(x, y) && entityAt(x, y) == null && !objectAt(x, y);
  }
}
