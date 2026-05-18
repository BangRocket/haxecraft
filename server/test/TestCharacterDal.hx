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

  function testInventoryRoundTrips() {
    var charId = charDal.autoCreate(seedAccountId, "test_char_seed");
    charDal.saveInventory(charId, [
      { itemTypeId: 1, count: 7 },
      { itemTypeId: 54, count: 1 },
      { itemTypeId: 12, count: 3 },
    ]);
    var loaded = charDal.loadInventory(charId);
    Assert.equals(3, loaded.length);
    Assert.equals(1, loaded[0].itemTypeId);
    Assert.equals(7, loaded[0].count);
    Assert.equals(54, loaded[1].itemTypeId);
    Assert.equals(3, loaded[2].count);
  }

  function testSaveInventoryReplaces() {
    var charId = charDal.autoCreate(seedAccountId, "test_char_seed");
    charDal.saveInventory(charId, [{ itemTypeId: 1, count: 5 }]);
    charDal.saveInventory(charId, [{ itemTypeId: 2, count: 9 }]);
    var loaded = charDal.loadInventory(charId);
    Assert.equals(1, loaded.length);
    Assert.equals(2, loaded[0].itemTypeId);
    Assert.equals(9, loaded[0].count);
  }

  function testLoadInventoryEmptyByDefault() {
    var charId = charDal.autoCreate(seedAccountId, "test_char_seed");
    Assert.equals(0, charDal.loadInventory(charId).length);
  }
}
