package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgCraft;
import shared.proto.MsgPlaceFurniture;
import shared.proto.MsgEntitySpawn;
import shared.proto.MsgType;

/** Crafting + furniture-placement message handlers. */
class CraftHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler) {
    this.sim = sim;
    this.enterHandler = enterHandler;
  }

  function actor(conn:ClientConnection):Null<Mobile> {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return null;
    return sim.mobileBySerial(entId);
  }

  /** MsgCraft — craft a recipe at a nearby station. */
  public function handleCraft(conn:ClientConnection, payload:Bytes):Void {
    var m = actor(conn);
    if (m == null) return;
    var req = MsgCraft.deserialize(new BytesInput(payload));
    if (Crafting.craft(sim, m, req.recipeId)) {
      InventoryHandler.send(m);
    }
  }

  /** MsgPlaceFurniture — place the held furniture item into the world. */
  public function handlePlace(conn:ClientConnection, payload:Bytes):Void {
    var m = actor(conn);
    if (m == null) return;
    var req = MsgPlaceFurniture.deserialize(new BytesInput(payload));
    var obj = Crafting.place(sim, m, req.tileX, req.tileY);
    if (obj == null) return;

    InventoryHandler.send(m);

    var sp = new MsgEntitySpawn();
    sp.entityId = obj.serial;
    sp.itemTypeId = (obj.itemType : Int);
    sp.count = obj.count;
    sp.tileX = obj.tileX;
    sp.tileY = obj.tileY;
    var out = new BytesOutput(); sp.serialize(out);
    var bytes = out.getBytes();
    for (other in sim.allMobiles()) {
      if (other.conn != null && other.conn.alive) other.conn.sendFrame(MsgType.ENTITY_SPAWN, bytes);
    }
  }
}
