package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;

class TestDbClient extends Test {
  var db:DbClient;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
  }

  function teardownClass() {
    if (db != null) db.close();
  }

  function testTrivialQuery() {
    var rows = db.query("SELECT 1 AS one", []);
    Assert.equals(1, rows.length);
    Assert.equals(1, (rows[0].one : Int));
  }

  function testParameterizedQueryEscapesSafely() {
    var rows = db.query("SELECT ? AS s", ["it's fine"]);
    Assert.equals(1, rows.length);
    Assert.equals("it's fine", (rows[0].s : String));
  }

  function testAccountsTableExists() {
    var rows = db.query(
      "SELECT column_name FROM information_schema.columns WHERE table_schema = 'haxecraft' AND table_name = 'accounts' ORDER BY ordinal_position",
      []
    );
    Assert.equals(6, rows.length);
  }

  function testTooFewParamsThrows() {
    Assert.raises(() -> db.query("SELECT ? AS x", []));
  }

  function testTooManyParamsThrows() {
    Assert.raises(() -> db.query("SELECT 1", [42]));
  }
}
