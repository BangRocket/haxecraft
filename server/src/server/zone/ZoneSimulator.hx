package server.zone;

import shared.Constants;
import shared.world.MapData;
import shared.world.Direction;

/** A tile step applied during a tick; the caller turns these into MsgEntityMove. */
typedef MoveResult = { entityId:Int, fromX:Int, fromY:Int, toX:Int, toY:Int };

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

  var characterDal:server.db.CharacterDal;

  public function new(map:MapData, ?characterDal:server.db.CharacterDal) {
    this.map = map;
    this.characterDal = characterDal;
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
    }
    markFlushed();
  }

  public function tick():Void {
    currentTick++;
    movesThisTick = [];
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
    }
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
