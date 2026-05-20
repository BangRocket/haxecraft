package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;
import shared.proto.MsgType;
import shared.proto.MsgCombatEvent;
import haxe.io.BytesInput;
import HeadlessClient;

class TestZoneCombat extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var userA:String = "test_combat_a";
  var userB:String = "test_combat_b";
  var pw:String = "test_pw";

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    accountDal = new AccountDal(db);
    for (u in [userA, userB]) {
      db.exec("DELETE FROM items WHERE parent_serial IN (SELECT serial FROM mobiles WHERE name = ?)", [u]);
      db.exec("DELETE FROM mobiles WHERE name = ?", [u]);
      db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      accountDal.create(u, PasswordHash.hash(pw));
    }
  }

  function teardownClass() {
    if (db != null) {
      for (u in [userA, userB]) {
        db.exec("DELETE FROM items WHERE parent_serial IN (SELECT serial FROM mobiles WHERE name = ?)", [u]);
        db.exec("DELETE FROM mobiles WHERE name = ?", [u]);
        db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      }
      db.close();
    }
  }

  // PRECONDITION: gateway + zone running on 127.0.0.1:7777/7778.

  function plantAdjacent(a:String, b:String):Void {
    db.exec("UPDATE mobiles SET tile_x = 500, tile_y = 500, hp = max_hp WHERE name = ?", [a]);
    db.exec("UPDATE mobiles SET tile_x = 501, tile_y = 500, hp = max_hp WHERE name = ?", [b]);
  }

  static function sawHit(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>):Bool {
    for (f in frames) if (f.msgType == (MsgType.COMBAT_EVENT : Int)) {
      var e = MsgCombatEvent.deserialize(new BytesInput(f.payload));
      if (e.hit) return true;
    }
    return false;
  }

  function loginClient(user:String):HeadlessClient {
    var c = new HeadlessClient();
    c.connectGateway();
    Assert.isTrue(c.login(user, pw));
    return c;
  }

  function testAdjacentSwingsReachDefender() {
    // First login autocreates the mobiles via the zone autocreate path.
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    cA.enterZone();
    cB.enterZone();
    cA.close(); cB.close();
    Sys.sleep(0.7);                         // let the zone flush + persist

    plantAdjacent(userA, userB);

    cA = loginClient(userA);
    cB = loginClient(userB);
    cA.enterZone();
    cB.enterZone();
    Sys.sleep(0.5);                         // let interest mutual-spawn settle

    cA.attack(cB.entityId);

    var saw = false;
    var deadline = haxe.Timer.stamp() + 5.0;
    while (haxe.Timer.stamp() < deadline) {
      if (sawHit(cB.drainFrames(0.5))) { saw = true; break; }
    }
    Assert.isTrue(saw, "defender's client received at least one MsgCombatEvent hit");

    cA.attack(0);                           // disengage
    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }
}
