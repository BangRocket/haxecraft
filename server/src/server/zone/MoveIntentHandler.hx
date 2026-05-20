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

  /** Records the latest held direction on the mobile. The move itself is
      applied in ZoneSimulator.tick() so the step cadence stays tick-aligned. */
  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) {
      Sys.println('[zone] conn ${conn.id} sent MoveIntent before EnterZone - dropping');
      conn.close();
      return;
    }
    var m = sim.mobileBySerial(entId);
    if (m == null) return;

    var req = MsgMoveIntent.deserialize(new BytesInput(payload));
    m.pendingDir = (req.dir : Int);
  }

  /** Broadcasts every move ZoneSimulator applied this tick. */
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

      for (m in sim.allMobiles()) {
        if (m.conn != null && m.conn.alive && interest.knows(m.serial, mv.entityId)) {
          m.conn.sendFrame(MsgType.ENTITY_MOVE, bytes);
        }
      }
    }
  }
}
