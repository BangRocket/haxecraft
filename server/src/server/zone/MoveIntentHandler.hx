package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.Constants;
import shared.proto.MsgMoveIntent;
import shared.proto.MsgEntityMove;
import shared.proto.MsgType;
import shared.world.Direction;

class MoveIntentHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler) {
    this.sim = sim;
    this.enterHandler = enterHandler;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) {
      Sys.println('[zone] conn ${conn.id} sent MoveIntent before EnterZone - dropping');
      conn.close();
      return;
    }
    var ent = sim.entityById(entId);
    if (ent == null) return;

    if (sim.currentTick < ent.nextMoveTick) {
      // Rate-limited; ignore silently.
      return;
    }

    var req = MsgMoveIntent.deserialize(new BytesInput(payload));
    var dir:Direction = cast req.dir;
    var dx = dir.dx();
    var dy = dir.dy();
    if (dx == 0 && dy == 0) return;

    var nx = ent.tileX + dx;
    var ny = ent.tileY + dy;
    if (!sim.map.isWalkable(nx, ny)) return;
    if (sim.entityAt(nx, ny) != null) return;

    var fromX = ent.tileX, fromY = ent.tileY;
    ent.tileX = nx;
    ent.tileY = ny;
    ent.nextMoveTick = sim.currentTick + Constants.MOVE_TICKS;

    var durMs = Constants.MOVE_TICKS * Std.int(1000 / Constants.TICK_HZ);
    var ev = new MsgEntityMove();
    ev.entityId = ent.id;
    ev.fromX = fromX; ev.fromY = fromY;
    ev.toX = nx; ev.toY = ny;
    ev.durationMs = durMs;
    var out = new BytesOutput(); ev.serialize(out);
    var bytes = out.getBytes();

    for (e in sim.allEntities()) {
      if (e.conn != null && e.conn.alive) {
        e.conn.sendFrame(MsgType.ENTITY_MOVE, bytes);
      }
    }
  }
}
