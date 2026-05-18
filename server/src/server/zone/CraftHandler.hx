package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgCraft;
import shared.proto.MsgPlaceFurniture;
import shared.proto.MsgWorldObjectSpawn;
import shared.proto.MsgType;

/** Crafting + furniture-placement message handlers. */
class CraftHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler) {
    this.sim = sim;
    this.enterHandler = enterHandler;
  }

  function actor(conn:ClientConnection):Null<Character> {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return null;
    return sim.entityById(entId);
  }

  /** MsgCraft — craft a recipe at a nearby station. */
  public function handleCraft(conn:ClientConnection, payload:Bytes):Void {
    var ent = actor(conn);
    if (ent == null) return;
    var req = MsgCraft.deserialize(new BytesInput(payload));
    if (Crafting.craft(sim, ent, req.recipeId)) {
      InventoryHandler.send(ent);  // inputs consumed, output added
    }
  }

  /** MsgPlaceFurniture — place the held furniture item into the world. */
  public function handlePlace(conn:ClientConnection, payload:Bytes):Void {
    var ent = actor(conn);
    if (ent == null) return;
    var req = MsgPlaceFurniture.deserialize(new BytesInput(payload));
    var obj = Crafting.place(sim, ent, req.tileX, req.tileY);
    if (obj == null) return;

    InventoryHandler.send(ent);  // furniture item consumed

    var sp = new MsgWorldObjectSpawn();
    sp.objectId = obj.id;
    sp.objectTypeId = (obj.objectType : Int);
    sp.tileX = obj.tileX;
    sp.tileY = obj.tileY;
    var out = new BytesOutput(); sp.serialize(out);
    var bytes = out.getBytes();
    for (e in sim.allEntities()) {
      if (e.conn != null && e.conn.alive) e.conn.sendFrame(MsgType.WORLD_OBJECT_SPAWN, bytes);
    }
  }
}
