package client.render;

import shared.world.Direction;

/** Client-side render state for one networked entity. */
class EntityVisual {
  public var id:Int;
  public var name:String;
  public var fromX:Float = 0;
  public var fromY:Float = 0;
  public var toX:Float = 0;
  public var toY:Float = 0;
  public var moveStartTime:Float = 0;
  public var moveDurationS:Float = 0;
  public var facing:Direction = SOUTH;

  public function new(id:Int, name:String) {
    this.id = id;
    this.name = name;
  }

  public function spawnAt(tileX:Int, tileY:Int):Void {
    fromX = toX = tileX;
    fromY = toY = tileY;
  }

  public function applyMove(toX:Int, toY:Int, durationMs:Int):Void {
    var cur = currentPos();
    var dx = toX - this.toX;
    var dy = toY - this.toY;
    if (dx > 0) facing = EAST;
    else if (dx < 0) facing = WEST;
    else if (dy > 0) facing = SOUTH;
    else if (dy < 0) facing = NORTH;
    fromX = cur.x;
    fromY = cur.y;
    this.toX = toX;
    this.toY = toY;
    moveStartTime = haxe.Timer.stamp();
    moveDurationS = durationMs / 1000.0;
  }

  /** Interpolated tile-space position. */
  public function currentPos():{x:Float, y:Float} {
    if (moveDurationS <= 0) return {x: toX, y: toY};
    var elapsed = haxe.Timer.stamp() - moveStartTime;
    if (elapsed >= moveDurationS) return {x: toX, y: toY};
    var t = elapsed / moveDurationS;
    return {
      x: fromX + (toX - fromX) * t,
      y: fromY + (toY - fromY) * t
    };
  }

  /** True while a move interpolation is in progress. */
  public function isMoving():Bool {
    if (moveDurationS <= 0) return false;
    return (haxe.Timer.stamp() - moveStartTime) < moveDurationS;
  }

  /** 0 or 1 — walk-cycle phase, advances while moving. */
  public function walkPhase():Int {
    if (!isMoving()) return 0;
    var elapsed = haxe.Timer.stamp() - moveStartTime;
    return Std.int(elapsed / (moveDurationS / 2)) % 2;
  }
}
