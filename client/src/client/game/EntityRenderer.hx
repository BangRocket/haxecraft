package client.game;

import h2d.Object;
import h2d.Graphics;

private class EntityVisual {
  public var id:Int;
  public var name:String;
  public var fromX:Float = 0;
  public var fromY:Float = 0;
  public var toX:Float = 0;
  public var toY:Float = 0;
  public var moveStartTime:Float = 0;
  public var moveDurationS:Float = 0;
  public function new(id:Int, name:String) { this.id = id; this.name = name; }
}

class EntityRenderer extends Object {
  var entities:Map<Int, EntityVisual> = new Map();
  var camera:Camera;
  var gfx:Graphics;
  var ownEntityId:Int;

  public function new(parent:Object, camera:Camera, ownEntityId:Int) {
    super(parent);
    this.camera = camera;
    this.ownEntityId = ownEntityId;
    this.gfx = new Graphics(this);
  }

  public function spawn(id:Int, name:String, tileX:Int, tileY:Int):Void {
    var v = new EntityVisual(id, name);
    v.fromX = v.toX = tileX;
    v.fromY = v.toY = tileY;
    entities.set(id, v);
  }

  public function despawn(id:Int):Void {
    entities.remove(id);
  }

  public function applyMove(id:Int, fromX:Int, fromY:Int, toX:Int, toY:Int, durationMs:Int):Void {
    var v = entities.get(id);
    if (v == null) return;
    // Start animation from CURRENT visual position to avoid snap.
    var cur = currentVisualPos(v);
    v.fromX = cur.x;
    v.fromY = cur.y;
    v.toX = toX;
    v.toY = toY;
    v.moveStartTime = haxe.Timer.stamp();
    v.moveDurationS = durationMs / 1000.0;
  }

  public function ownTilePosition():{x:Int, y:Int} {
    var v = entities.get(ownEntityId);
    if (v == null) return { x: 0, y: 0 };
    return { x: Std.int(v.toX), y: Std.int(v.toY) };
  }

  public function redraw():Void {
    gfx.clear();
    var ts = camera.pixelTileSize;
    for (v in entities) {
      var p = currentVisualPos(v);
      var px = camera.tileToScreenX(p.x);
      var py = camera.tileToScreenY(p.y);
      var color = (v.id == ownEntityId) ? 0xffd83a3a : 0xffe6c84a;
      gfx.beginFill(color & 0xffffff, 1.0);
      gfx.drawRect(px, py, ts, ts);
      gfx.endFill();
    }
  }

  function currentVisualPos(v:EntityVisual):{x:Float, y:Float} {
    if (v.moveDurationS <= 0) return { x: v.toX, y: v.toY };
    var elapsed = haxe.Timer.stamp() - v.moveStartTime;
    if (elapsed >= v.moveDurationS) return { x: v.toX, y: v.toY };
    var t = elapsed / v.moveDurationS;
    return {
      x: v.fromX + (v.toX - v.fromX) * t,
      y: v.fromY + (v.toY - v.fromY) * t
    };
  }
}
