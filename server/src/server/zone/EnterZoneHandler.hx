package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import server.db.MobileDal;
import server.db.ItemDal;
import server.db.AccountDal;
import shared.Constants;
import shared.proto.MsgEnterZone;
import shared.proto.MsgEnterZoneAck;
import shared.proto.MsgType;
import shared.security.HandoffToken;
import shared.item.ItemType;

class EnterZoneHandler {
  var mobileDal:MobileDal;
  var itemDal:ItemDal;
  var accountDal:AccountDal;
  var sim:ZoneSimulator;
  // conn.id -> mobile.serial
  var connToEntity:Map<Int, Int> = new Map();

  public function new(mobileDal:MobileDal, itemDal:ItemDal,
                      accountDal:AccountDal, sim:ZoneSimulator) {
    this.mobileDal = mobileDal;
    this.itemDal = itemDal;
    this.accountDal = accountDal;
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

    var row = mobileDal.findByAccountId(parsed.accountId);

    // Autocreate path: token carried characterId=0 (gateway found no mobile).
    if (row == null) {
      if (parsed.characterId != 0) {
        ack.success = false;
        ack.errorMsg = "character not found";
        Sys.println('[zone] conn ${conn.id} EnterZone REJECT (char missing acct=${parsed.accountId} char=${parsed.characterId})');
        sendAck(conn, ack);
        conn.close();
        return;
      }
      var acct = accountDal.findById(parsed.accountId);
      if (acct == null) {
        ack.success = false;
        ack.errorMsg = "account not found";
        Sys.println('[zone] conn ${conn.id} EnterZone REJECT (no account ${parsed.accountId})');
        sendAck(conn, ack);
        conn.close();
        return;
      }
      var newSerial = sim.serials.nextMobile();
      try {
        mobileDal.insert(newSerial, parsed.accountId, acct.username, 1,
                         Constants.DEFAULT_SPAWN_X, Constants.DEFAULT_SPAWN_Y);
      } catch (err:Dynamic) {
        ack.success = false;
        ack.errorMsg = "could not create character";
        Sys.println('[zone] conn ${conn.id} autocreate failed: $err');
        sendAck(conn, ack);
        conn.close();
        return;
      }
      Sys.println('[zone] autocreated mobile serial=$newSerial name=${acct.username}');
      row = mobileDal.findByAccountId(parsed.accountId);
    } else if (parsed.characterId != 0 && row.serial != parsed.characterId) {
      ack.success = false;
      ack.errorMsg = "character mismatch";
      Sys.println('[zone] conn ${conn.id} EnterZone REJECT (token char=${parsed.characterId} but found ${row.serial})');
      sendAck(conn, ack);
      conn.close();
      return;
    }

    if (sim.mobileBySerial(row.serial) != null) {
      ack.success = false;
      ack.errorMsg = "character already in zone";
      Sys.println('[zone] conn ${conn.id} EnterZone REJECT (already in zone, mobile=${row.serial})');
      sendAck(conn, ack);
      conn.close();
      return;
    }

    // If saved position isn't walkable (procgen spawn in water/rock/tree), relocate.
    var sx = row.tileX, sy = row.tileY;
    if (!sim.map.isWalkable(sx, sy) || sim.entityAt(sx, sy) != null) {
      var p = sim.map.findWalkableNear(sx, sy);
      Sys.println('[zone] relocating mobile ${row.serial} from ($sx,$sy) -> (${p.x},${p.y})');
      sx = p.x; sy = p.y;
    }

    ack.success = true;
    ack.entityId = row.serial;
    ack.tileX = sx;
    ack.tileY = sy;
    sendAck(conn, ack);

    var runtime = new Mobile(row.serial, row.name, conn, sx, sy);

    // Load persisted carried items BEFORE spawn() so the persistence hooks
    // (installed by spawn) don't fire spurious DAL writes on load.
    for (r in itemDal.loadCarriedFor(row.serial)) {
      var it = new Item(r.serial, r.itemTypeId, r.count);
      it.slot = r.slot == null ? 0 : r.slot;
      sim.attachCarriedItem(runtime, it);
    }
    sim.spawn(runtime);
    connToEntity.set(conn.id, row.serial);
    Sys.println('[zone] conn ${conn.id} spawned mobile=${row.serial} at ($sx,$sy)');

    // Bootstrap: an empty inventory gets the basic wood tool kit, so the
    // gather -> craft loop is reachable from a fresh start.
    if (runtime.inventory.isEmpty()) {
      var kit = [ItemType.WOOD_PICKAXE, ItemType.WOOD_AXE, ItemType.WOOD_SHOVEL, ItemType.WOOD_HOE];
      for (t in kit) {
        var it = new Item(sim.serials.nextItem(), t, 1);
        runtime.inventory.addFresh(it);
      }
    }

    // Echo spawn back so the joiner sees itself.
    var sp = new shared.proto.MsgEntitySpawn();
    sp.entityId = runtime.serial;
    sp.name = runtime.name;
    sp.tileX = runtime.tileX;
    sp.tileY = runtime.tileY;
    var spOut = new BytesOutput(); sp.serialize(spOut);
    conn.sendFrame(MsgType.ENTITY_SPAWN, spOut.getBytes());

    // SP3: send the joining client its inventory.
    InventoryHandler.send(runtime);

    // SP2: send the zone's world items (ground items + placed furniture) to
    // the joining client as unified MsgEntitySpawn frames.
    for (it in sim.items) {
      if (!it.inWorld()) continue;
      var sp = new shared.proto.MsgEntitySpawn();
      sp.entityId = it.serial;
      sp.itemTypeId = (it.itemType : Int);
      sp.count = it.count;
      sp.tileX = it.tileX;
      sp.tileY = it.tileY;
      var o = new BytesOutput(); sp.serialize(o);
      conn.sendFrame(MsgType.ENTITY_SPAWN, o.getBytes());
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
