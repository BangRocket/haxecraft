package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.Constants;
import shared.proto.MsgMoveIntent;
import shared.proto.MsgEntityMove;
import shared.proto.MsgType;

class MoveIntentHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;
  var interest:InterestManager;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler, interest:InterestManager) {
    this.sim = sim;
    this.enterHandler = enterHandler;
    this.interest = interest;
  }

  /** Records the latest held direction on the entity. The move itself is
      applied in ZoneSimulator.tick() so the step cadence stays tick-aligned
      — see broadcastMoves(). */
  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) {
      Sys.println('[zone] conn ${conn.id} sent MoveIntent before EnterZone - dropping');
      conn.close();
      return;
    }
    var ent = sim.entityById(entId);
    if (ent == null) return;

    var req = MsgMoveIntent.deserialize(new BytesInput(payload));
    ent.pendingDir = (req.dir : Int);
  }

  /** Broadcasts every move ZoneSimulator applied this tick. Call once per
      tick, immediately after sim.tick(). */
  public function broadcastMoves():Void {
    var moves = sim.movesThisTick;
    if (moves.length == 0) return;

    var durMs = Constants.MOVE_TICKS * Std.int(1000 / Constants.TICK_HZ);
    for (mv in moves) {
      var ev = new MsgEntityMove();
      ev.entityId = mv.entityId;
      ev.fromX = mv.fromX; ev.fromY = mv.fromY;
      ev.toX = mv.toX; ev.toY = mv.toY;
      ev.durationMs = durMs;
      var out = new BytesOutput(); ev.serialize(out);
      var bytes = out.getBytes();

      for (e in sim.allEntities()) {
        if (e.conn != null && e.conn.alive && interest.knows(e.id, mv.entityId)) {
          e.conn.sendFrame(MsgType.ENTITY_MOVE, bytes);
        }
      }
    }
  }
}
