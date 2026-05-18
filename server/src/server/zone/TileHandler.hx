package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgUseItemOnTile;
import shared.proto.MsgTileChange;
import shared.proto.MsgGroundItemSpawn;
import shared.proto.MsgType;

/** Tile interaction networking: the use-on-tile intent and the per-tick
    broadcast of tile changes + drop spawns. */
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
    var ent = sim.entityById(entId);
    if (ent == null) return;
    var req = MsgUseItemOnTile.deserialize(new BytesInput(payload));
    // Reach: the target tile must be on or next to the actor.
    if (Math.abs(req.tileX - ent.tileX) > 1 || Math.abs(req.tileY - ent.tileY) > 1) return;
    if (TileInteraction.apply(sim, ent, req.tileX, req.tileY)) {
      InventoryHandler.send(ent);  // planting may have consumed a resource
    }
  }

  /** Broadcast tile changes + drop spawns accumulated since the last flush.
      Call once per tick, after sim.tick(). */
  public function flush():Void {
    if (sim.pendingTileChanges.length == 0 && sim.pendingItemSpawns.length == 0) return;

    for (tc in sim.pendingTileChanges) {
      var m = new MsgTileChange();
      m.tileX = tc.x; m.tileY = tc.y; m.tileType = tc.type; m.data = tc.data;
      var out = new BytesOutput(); m.serialize(out);
      broadcast(MsgType.TILE_CHANGE, out.getBytes());
    }
    for (gi in sim.pendingItemSpawns) {
      var m = new MsgGroundItemSpawn();
      m.worldItemId = gi.id;
      m.itemTypeId = (gi.itemType : Int);
      m.count = gi.count;
      m.tileX = gi.tileX; m.tileY = gi.tileY;
      var out = new BytesOutput(); m.serialize(out);
      broadcast(MsgType.GROUND_ITEM_SPAWN, out.getBytes());
    }
    sim.clearPending();
  }

  function broadcast(msgType:Int, bytes:Bytes):Void {
    for (e in sim.allEntities()) {
      if (e.conn != null && e.conn.alive) e.conn.sendFrame(msgType, bytes);
    }
  }
}
