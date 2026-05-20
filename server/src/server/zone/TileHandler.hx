package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgUseItemOnTile;
import shared.proto.MsgTileChange;
import shared.proto.MsgEntitySpawn;
import shared.proto.MsgType;

/** Tile interaction networking: the use-on-tile intent and the per-tick
    broadcast of tile changes + item spawns (gathering drops, planting, etc). */
class TileHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler) {
    this.sim = sim;
    this.enterHandler = enterHandler;
  }

  /** MsgUseItemOnTile — gather/plant on a tile adjacent to the actor. */
  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return;
    var m = sim.mobileBySerial(entId);
    if (m == null) return;
    var req = MsgUseItemOnTile.deserialize(new BytesInput(payload));
    if (Math.abs(req.tileX - m.tileX) > 1 || Math.abs(req.tileY - m.tileY) > 1) return;
    if (TileInteraction.apply(sim, m, req.tileX, req.tileY)) {
      InventoryHandler.send(m);  // planting may have consumed a resource
    }
  }

  /** Broadcast tile changes + item spawns accumulated since the last flush. */
  public function flush():Void {
    if (sim.pendingTileChanges.length == 0 && sim.pendingItemSpawns.length == 0) return;

    for (tc in sim.pendingTileChanges) {
      var m = new MsgTileChange();
      m.tileX = tc.x; m.tileY = tc.y; m.tileType = tc.type; m.data = tc.data;
      var out = new BytesOutput(); m.serialize(out);
      broadcast(MsgType.TILE_CHANGE, out.getBytes());
    }
    for (it in sim.pendingItemSpawns) {
      var sp = new MsgEntitySpawn();
      sp.entityId = it.serial;
      sp.itemTypeId = (it.itemType : Int);
      sp.count = it.count;
      sp.tileX = it.tileX; sp.tileY = it.tileY;
      var out = new BytesOutput(); sp.serialize(out);
      broadcast(MsgType.ENTITY_SPAWN, out.getBytes());
    }
    sim.clearPending();
  }

  function broadcast(msgType:Int, bytes:Bytes):Void {
    for (m in sim.allMobiles()) {
      if (m.conn != null && m.conn.alive) m.conn.sendFrame(msgType, bytes);
    }
  }
}
