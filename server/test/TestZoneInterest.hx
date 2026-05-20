package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;
import shared.world.Direction;
import shared.proto.MsgType;
import shared.proto.MsgEntitySpawn;
import shared.proto.MsgEntityMove;
import haxe.io.BytesInput;
import HeadlessClient;

class TestZoneInterest extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var userA:String = "test_interest_a";
  var userB:String = "test_interest_b";
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

  function plant(name:String, x:Int, y:Int):Void {
    db.exec("UPDATE mobiles SET tile_x = ?, tile_y = ? WHERE name = ?", [x, y, name]);
  }

  // Log in (autocreates the character), returns the connected client.
  function loginClient(user:String):HeadlessClient {
    var c = new HeadlessClient();
    c.connectGateway();
    Assert.isTrue(c.login(user, pw));
    return c;
  }

  static function sawSpawn(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>, entityId:Int):Bool {
    for (f in frames) if (f.msgType == (MsgType.ENTITY_SPAWN : Int)) {
      if (MsgEntitySpawn.deserialize(new BytesInput(f.payload)).entityId == entityId) return true;
    }
    return false;
  }

  static function sawMove(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>, entityId:Int):Bool {
    for (f in frames) if (f.msgType == (MsgType.ENTITY_MOVE : Int)) {
      if (MsgEntityMove.deserialize(new BytesInput(f.payload)).entityId == entityId) return true;
    }
    return false;
  }

  // Try each cardinal once; return true on the first accepted move.
  static function moveOnce(c:HeadlessClient):Bool {
    for (d in [Direction.EAST, Direction.WEST, Direction.NORTH, Direction.SOUTH]) {
      if (c.move(d)) return true;
      Sys.sleep(0.25);
    }
    return false;
  }

  function testNearbyPlayersSeeEachOther() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 308, 512);          // 8 tiles apart — inside SPAWN_EXTENT
    cA.enterZone();
    cB.enterZone();

    Assert.isTrue(sawSpawn(cA.drainFrames(0.6), cB.entityId), "A should see B spawn");
    Assert.isTrue(sawSpawn(cB.drainFrames(0.6), cA.entityId), "B should see A spawn");

    Assert.isTrue(moveOnce(cA), "expected an accepted move for A");
    Assert.isTrue(sawMove(cB.drainFrames(0.6), cA.entityId), "B should see A's move");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }

  function testDistantPlayersAreFiltered() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 800, 512);          // 500 tiles apart — far beyond AOI
    cA.enterZone();
    cB.enterZone();

    Assert.isFalse(sawSpawn(cA.drainFrames(0.6), cB.entityId), "A must not see distant B");

    Assert.isTrue(moveOnce(cA), "expected an accepted move for A");
    Assert.isFalse(sawMove(cB.drainFrames(0.6), cA.entityId), "B must not see distant A's move");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }
}
