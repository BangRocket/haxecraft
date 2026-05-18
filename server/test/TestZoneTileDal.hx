package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.ZoneTileDal;

class TestZoneTileDal extends Test {
  var db:DbClient;
  var dal:ZoneTileDal;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    dal = new ZoneTileDal(db);
  }

  function teardownClass() {
    if (db != null) db.close();
  }

  function setup() {
    db.exec("DELETE FROM zone_tile_overrides", []);
  }

  function testUpsertAndLoad() {
    dal.upsert(10, 20, 7, 0);
    dal.upsert(11, 20, 16, 3);
    Assert.equals(2, dal.loadOverrides().length);
  }

  function testUpsertReplacesSameTile() {
    dal.upsert(5, 5, 6, 0);
    dal.upsert(5, 5, 1, 0);  // same (x, y) key
    var rows = dal.loadOverrides();
    Assert.equals(1, rows.length);
    Assert.equals(1, rows[0].tileType);
  }

  function testEmptyByDefault() {
    Assert.equals(0, dal.loadOverrides().length);
  }
}
