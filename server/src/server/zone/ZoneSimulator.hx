package server.zone;

import shared.world.MapData;

class ZoneSimulator {
  public var currentTick(default, null):Int = 0;
  public var map(default, null):MapData;
  var entities:Map<Int, Character> = new Map();

  public function new(map:MapData) {
    this.map = map;
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
}
