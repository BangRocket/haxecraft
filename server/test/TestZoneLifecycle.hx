package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import server.db.CharacterDal;
import shared.security.PasswordHash;
import shared.world.Direction;
import HeadlessClient;

class TestZoneLifecycle extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var characterDal:CharacterDal;
  var username:String = "test_zone_walker";
  var password:String = "test_pw";

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    accountDal = new AccountDal(db);
    characterDal = new CharacterDal(db);
    db.exec("DELETE FROM characters WHERE name = ?", [username]);
    db.exec("DELETE FROM accounts  WHERE username = ?", [username]);
    accountDal.create(username, PasswordHash.hash(password));
  }

  function teardownClass() {
    if (db != null) {
      db.exec("DELETE FROM characters WHERE name = ?", [username]);
      db.exec("DELETE FROM accounts  WHERE username = ?", [username]);
      db.close();
    }
  }

  // PRECONDITION: gateway + zone running on 127.0.0.1:7777/7778.

  function testWalkPersistsAcrossLogout() {
    var c1 = new HeadlessClient();
    c1.connectGateway();
    Assert.isTrue(c1.login(username, password));
    c1.enterZone();
    Assert.isTrue(c1.groundItemCount >= 1, "expected ground items in the zone-entry burst");
    Assert.isTrue(c1.worldObjectCount >= 1, "expected world objects in the zone-entry burst");
    var spawnX = c1.tileX;
    var spawnY = c1.tileY;

    function waitTick() Sys.sleep(0.25);

    // The starter map is procgen, so we can't assume any specific direction
    // is walkable from spawn. Probe all 4 cardinals; walk a few steps in
    // whichever directions succeed. Accept any nonzero total displacement.
    var allDirs:Array<Direction> = [Direction.EAST, Direction.WEST, Direction.NORTH, Direction.SOUTH];
    var totalDx = 0, totalDy = 0;
    var totalAccepted = 0;
    for (d in allDirs) {
      for (_ in 0...3) {
        if (c1.move(d)) {
          totalDx += d.dx();
          totalDy += d.dy();
          totalAccepted++;
        }
        waitTick();
      }
    }
    Assert.isTrue(totalAccepted > 0, "expected at least one accepted move on a 1024x1024 procgen map");
    var expectedX = spawnX + totalDx;
    var expectedY = spawnY + totalDy;

    Assert.equals(expectedX, c1.tileX);
    Assert.equals(expectedY, c1.tileY);
    c1.close();

    // Give the zone time to detect the disconnect and write position to DB.
    Sys.sleep(0.7);

    // Second session: reconnect, EnterZoneAck must report the saved position.
    var c2 = new HeadlessClient();
    c2.connectGateway();
    Assert.isTrue(c2.login(username, password));
    c2.enterZone();
    Assert.equals(expectedX, c2.tileX);
    Assert.equals(expectedY, c2.tileY);
    c2.close();
  }
}
