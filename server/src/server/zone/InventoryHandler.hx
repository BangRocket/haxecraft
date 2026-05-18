package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgInventory;
import shared.proto.MsgGroundItemDespawn;
import shared.proto.MsgSelectActiveItem;
import shared.proto.MsgType;

/** Inventory networking: the active-slot intent, full-inventory sync, and
    the per-tick pickup broadcast. */
class InventoryHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler) {
    this.sim = sim;
    this.enterHandler = enterHandler;
  }

  /** MsgSelectActiveItem — choose the active inventory slot. */
  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return;
    var ent = sim.entityById(entId);
    if (ent == null) return;
    var req = MsgSelectActiveItem.deserialize(new BytesInput(payload));
    ent.inventory.activeSlot = req.slot;
  }

  /** Send a character its full inventory. */
  public static function send(ch:Character):Void {
    if (ch.conn == null || !ch.conn.alive) return;
    var m = new MsgInventory();
    m.activeSlot = ch.inventory.activeSlot;
    m.slots = ch.inventory.toRows();
    var out = new BytesOutput(); m.serialize(out);
    ch.conn.sendFrame(MsgType.INVENTORY, out.getBytes());
  }

  /** Despawn every item picked up this tick (broadcast) and resync the
      picker's inventory. Call once per tick, after sim.tick(). */
  public function broadcastPickups():Void {
    for (p in sim.pickupsThisTick) {
      var dp = new MsgGroundItemDespawn();
      dp.worldItemId = p.worldItemId;
      var dout = new BytesOutput(); dp.serialize(dout);
      var dbytes = dout.getBytes();
      for (e in sim.allEntities()) {
        if (e.conn != null && e.conn.alive) {
          e.conn.sendFrame(MsgType.GROUND_ITEM_DESPAWN, dbytes);
        }
      }
      send(p.entity);
    }
  }
}
