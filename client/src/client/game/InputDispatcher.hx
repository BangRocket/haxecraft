package client.game;

import client.net.TcpConnection;
import shared.Constants;
import shared.proto.MsgMoveIntent;
import shared.proto.MsgType;
import shared.world.Direction;

class InputDispatcher {
  var conn:TcpConnection;
  var minIntervalS:Float;
  var lastSentAt:Float = 0;

  public function new(conn:TcpConnection) {
    this.conn = conn;
    this.minIntervalS = (Constants.MOVE_TICKS / Constants.TICK_HZ) * 0.9;
  }

  public function update():Void {
    var now = haxe.Timer.stamp();
    if (now - lastSentAt < minIntervalS) return;

    var dir:Int = -1;
    if (hxd.Key.isDown(hxd.Key.W) || hxd.Key.isDown(hxd.Key.UP)) dir = Direction.NORTH;
    else if (hxd.Key.isDown(hxd.Key.S) || hxd.Key.isDown(hxd.Key.DOWN)) dir = Direction.SOUTH;
    else if (hxd.Key.isDown(hxd.Key.D) || hxd.Key.isDown(hxd.Key.RIGHT)) dir = Direction.EAST;
    else if (hxd.Key.isDown(hxd.Key.A) || hxd.Key.isDown(hxd.Key.LEFT)) dir = Direction.WEST;
    if (dir < 0) return;

    var m = new MsgMoveIntent();
    m.dir = dir;
    var out = new haxe.io.BytesOutput(); m.serialize(out);
    conn.sendFrame(MsgType.MOVE_INTENT, out.getBytes());
    lastSentAt = now;
  }
}
