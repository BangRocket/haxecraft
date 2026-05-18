package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import server.db.CharacterDal;
import server.zone.Character;
import shared.proto.MsgEnterZone;
import shared.proto.MsgEnterZoneAck;
import shared.proto.MsgType;
import shared.security.HandoffToken;
import shared.item.ItemType;

class EnterZoneHandler {
  var characterDal:CharacterDal;
  var sim:ZoneSimulator;
  var connToEntity:Map<Int, Int> = new Map();

  public function new(characterDal:CharacterDal, sim:ZoneSimulator) {
    this.characterDal = characterDal;
    this.sim = sim;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var req = MsgEnterZone.deserialize(new BytesInput(payload));
    var ack = new MsgEnterZoneAck();

    var parsed = HandoffToken.verify(req.handoffToken);
    if (parsed == null) {
      ack.success = false;
      ack.errorMsg = "invalid or expired handoff token";
      Sys.println('[zone] conn ${conn.id} EnterZone REJECT (bad token)');
      sendAck(conn, ack);
      conn.close();
      return;
    }

    var ch = characterDal.findByAccountId(parsed.accountId);
    if (ch == null || ch.id != parsed.characterId) {
      ack.success = false;
      ack.errorMsg = "character not found";
      Sys.println('[zone] conn ${conn.id} EnterZone REJECT (char missing acct=${parsed.accountId} char=${parsed.characterId})');
      sendAck(conn, ack);
      conn.close();
      return;
    }

    if (sim.entityById(ch.id) != null) {
      ack.success = false;
      ack.errorMsg = "character already in zone";
      Sys.println('[zone] conn ${conn.id} EnterZone REJECT (already in zone, char=${ch.id})');
      sendAck(conn, ack);
      conn.close();
      return;
    }

    // If saved position isn't walkable (procgen spawn in water/rock/tree), relocate.
    var sx = ch.tileX, sy = ch.tileY;
    if (!sim.map.isWalkable(sx, sy) || sim.entityAt(sx, sy) != null) {
      var p = sim.map.findWalkableNear(sx, sy);
      Sys.println('[zone] relocating char ${ch.id} from ($sx,$sy) -> (${p.x},${p.y})');
      sx = p.x; sy = p.y;
    }

    ack.success = true;
    ack.entityId = ch.id;
    ack.tileX = sx;
    ack.tileY = sy;
    sendAck(conn, ack);

    var runtime = new Character(ch.id, ch.name, conn, sx, sy);
    runtime.inventory = Inventory.fromRows(characterDal.loadInventory(ch.id));
    // Bootstrap: an empty inventory gets the basic wood tool kit, so the
    // gather -> craft loop is reachable from a fresh start.
    if (runtime.inventory.isEmpty()) {
      runtime.inventory.add(ItemType.WOOD_PICKAXE, 1);
      runtime.inventory.add(ItemType.WOOD_AXE, 1);
      runtime.inventory.add(ItemType.WOOD_SHOVEL, 1);
      runtime.inventory.add(ItemType.WOOD_HOE, 1);
    }
    sim.spawn(runtime);
    connToEntity.set(conn.id, ch.id);
    Sys.println('[zone] conn ${conn.id} spawned char=${ch.id} at (${ch.tileX},${ch.tileY})');

    // Echo spawn back so client sees itself.
    var sp = new shared.proto.MsgEntitySpawn();
    sp.entityId = runtime.id;
    sp.name = runtime.name;
    sp.tileX = runtime.tileX;
    sp.tileY = runtime.tileY;
    var spOut = new haxe.io.BytesOutput(); sp.serialize(spOut);
    var spBytes = spOut.getBytes();
    conn.sendFrame(shared.proto.MsgType.ENTITY_SPAWN, spBytes);

    // SP3: send the joining client its inventory.
    InventoryHandler.send(runtime);

    // Existing entities are synced to this client (and vice versa) by the
    // per-tick InterestManager diff in the zone loop.

    // SP2: send the zone's static world content to the joining client.
    for (o in sim.worldObjects) {
      var os = new shared.proto.MsgWorldObjectSpawn();
      os.objectId = o.id;
      os.objectTypeId = (o.objectType : Int);
      os.tileX = o.tileX; os.tileY = o.tileY;
      var oo = new haxe.io.BytesOutput(); os.serialize(oo);
      conn.sendFrame(shared.proto.MsgType.WORLD_OBJECT_SPAWN, oo.getBytes());
    }
    for (gi in sim.groundItems) {
      var gs = new shared.proto.MsgGroundItemSpawn();
      gs.worldItemId = gi.id;
      gs.itemTypeId = (gi.itemType : Int);
      gs.count = gi.count;
      gs.tileX = gi.tileX; gs.tileY = gi.tileY;
      var go = new haxe.io.BytesOutput(); gs.serialize(go);
      conn.sendFrame(shared.proto.MsgType.GROUND_ITEM_SPAWN, go.getBytes());
    }
  }

  public function entityIdForConn(conn:ClientConnection):Null<Int> {
    return connToEntity.get(conn.id);
  }

  public function forgetConn(conn:ClientConnection):Void {
    connToEntity.remove(conn.id);
  }

  static function sendAck(conn:ClientConnection, ack:MsgEnterZoneAck):Void {
    var out = new BytesOutput(); ack.serialize(out);
    conn.sendFrame(MsgType.ENTER_ZONE_ACK, out.getBytes());
  }
}
