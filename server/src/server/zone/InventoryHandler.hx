package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgInventory;
import shared.proto.MsgEntityMove;
import shared.proto.MsgEntityDespawn;
import shared.proto.MsgSelectActiveItem;
import shared.proto.MsgType;

/** Inventory networking: the active-slot intent, full-inventory sync, and
    the per-tick pickup broadcast.

    Pickup is wire-broadcast as a re-parent MsgEntityMove (item world → mobile
    inventory). If the pickup merged into an existing stack, the incoming
    item is destroyed — that path emits MsgEntityDespawn for it plus an
    MsgInventory refresh to the picker so the surviving slot's new count
    reaches their client. */
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
    var m = sim.mobileBySerial(entId);
    if (m == null) return;
    var req = MsgSelectActiveItem.deserialize(new BytesInput(payload));
    m.inventory.activeSlot = req.slot;
  }

  /** Send a mobile its full inventory. */
  public static function send(m:Mobile):Void {
    if (m.conn == null || !m.conn.alive) return;
    var msg = new MsgInventory();
    msg.activeSlot = m.inventory.activeSlot;
    msg.slots = m.inventory.toRows();
    var out = new BytesOutput(); msg.serialize(out);
    m.conn.sendFrame(MsgType.INVENTORY, out.getBytes());
  }

  /** Broadcast every pickup applied this tick. Call once per tick. */
  public function broadcastPickups():Void {
    for (p in sim.pickupsThisTick) {
      var it = sim.items.get(p.worldItemSerial);
      if (it != null && it.parent == p.entity) {
        // Non-merge re-parent: one MsgEntityMove with newParentSerial set.
        var mv = new MsgEntityMove();
        mv.entityId = it.serial;
        mv.fromX = it.tileX; mv.fromY = it.tileY;
        mv.toX = 0; mv.toY = 0;
        mv.durationMs = 0;
        mv.newParentSerial = p.entity.serial;
        mv.newSlot = it.slot;
        var out = new BytesOutput(); mv.serialize(out);
        var bytes = out.getBytes();
        for (m in sim.allMobiles()) {
          if (m.conn != null && m.conn.alive) {
            m.conn.sendFrame(MsgType.ENTITY_MOVE, bytes);
          }
        }
      } else {
        // Merge case: the picked Item was consumed (count bumped on an
        // existing stack). Despawn it for the world and refresh the picker's
        // inventory so the surviving slot's new count lands.
        var dp = new MsgEntityDespawn();
        dp.entityId = p.worldItemSerial;
        var out = new BytesOutput(); dp.serialize(out);
        var bytes = out.getBytes();
        for (m in sim.allMobiles()) {
          if (m.conn != null && m.conn.alive) {
            m.conn.sendFrame(MsgType.ENTITY_DESPAWN, bytes);
          }
        }
        send(p.entity);
      }
    }
  }
}
