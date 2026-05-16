package server.zone;

import shared.world.MapData;

class ZoneSimulator {
  public var currentTick(default, null):Int = 0;
  public var map(default, null):MapData;
  var entities:Map<Int, Character> = new Map();

  public var lastFlushTick:Int = 0;
  public static inline var FLUSH_TICK_INTERVAL:Int = 50;  // 5s at 10 Hz

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
    // Movement processing wired in Task 18.
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
}
