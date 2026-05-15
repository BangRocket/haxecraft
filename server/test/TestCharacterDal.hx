package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import server.db.CharacterDal;

class TestCharacterDal extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var charDal:CharacterDal;
  var seedAccountId:Int;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    accountDal = new AccountDal(db);
    charDal = new CharacterDal(db);
    db.exec("DELETE FROM characters WHERE name LIKE 'test\\_char\\_%'", []);
    db.exec("DELETE FROM accounts  WHERE username LIKE 'test\\_char\\_%'", []);
    seedAccountId = accountDal.create("test_char_seed", "x");
  }

  function teardownClass() {
    if (db != null) {
      db.exec("DELETE FROM characters WHERE name LIKE 'test\\_char\\_%'", []);
      db.exec("DELETE FROM accounts  WHERE username LIKE 'test\\_char\\_%'", []);
      db.close();
    }
  }

  // Reset character rows before each test so tests don't depend on execution order.
  function setup() {
    db.exec("DELETE FROM characters WHERE name LIKE 'test\\_char\\_%'", []);
  }

  function testFindByAccountReturnsNullWhenAbsent() {
    Assert.isNull(charDal.findByAccountId(seedAccountId));
  }

  function testAutoCreateThenFindRoundTrips() {
    var charId = charDal.autoCreate(seedAccountId, "test_char_seed");
    Assert.isTrue(charId > 0);
    var c = charDal.findByAccountId(seedAccountId);
    Assert.notNull(c);
    Assert.equals(charId, c.id);
    Assert.equals("test_char_seed", c.name);
    Assert.equals(512, c.tileX);
    Assert.equals(512, c.tileY);
  }

  function testSavePositionPersists() {
    var charId = charDal.autoCreate(seedAccountId, "test_char_seed");
    charDal.savePosition(charId, 100, 200);
    var c = charDal.findByAccountId(seedAccountId);
    Assert.equals(100, c.tileX);
    Assert.equals(200, c.tileY);
  }
}
