package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;

class TestAccountDal extends Test {
  var db:DbClient;
  var dal:AccountDal;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    dal = new AccountDal(db);
    db.exec("DELETE FROM accounts WHERE username LIKE 'test\\_%'", []);
  }

  function teardownClass() {
    if (db != null) {
      db.exec("DELETE FROM accounts WHERE username LIKE 'test\\_%'", []);
      db.close();
    }
  }

  function testCreateAndFind() {
    var id = dal.create("test_alice", "hash_abc");
    Assert.isTrue(id > 0);
    var acct = dal.findByUsername("test_alice");
    Assert.notNull(acct);
    Assert.equals("test_alice", acct.username);
    Assert.equals("hash_abc", acct.passwordHash);
  }

  function testFindMissingReturnsNull() {
    Assert.isNull(dal.findByUsername("test_no_such_user"));
  }

  function testDuplicateUsernameRejected() {
    dal.create("test_bob", "x");
    Assert.raises(() -> dal.create("test_bob", "y"));
  }
}
