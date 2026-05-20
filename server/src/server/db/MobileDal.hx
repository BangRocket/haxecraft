package server.db;

typedef MobileRow = {
  serial:Int,
  accountId:Null<Int>,
  name:String,
  zoneId:Int,
  tileX:Int,
  tileY:Int
};

class MobileDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function findByAccountId(accountId:Int):Null<MobileRow> {
    var rows = db.query(
      "SELECT serial, account_id, name, zone_id, tile_x, tile_y FROM mobiles WHERE account_id = ? LIMIT 1",
      [accountId]
    );
    if (rows.length == 0) return null;
    return rowOf(rows[0]);
  }

  /** Insert a new mobile with an allocated serial. */
  public function insert(serial:Int, accountId:Null<Int>, name:String,
                        zoneId:Int, tileX:Int, tileY:Int):Void {
    db.exec(
      "INSERT INTO mobiles (serial, account_id, name, zone_id, tile_x, tile_y) VALUES (?, ?, ?, ?, ?, ?)",
      [serial, accountId, name, zoneId, tileX, tileY]
    );
  }

  public function savePosition(serial:Int, tileX:Int, tileY:Int):Void {
    db.exec(
      "UPDATE mobiles SET tile_x = ?, tile_y = ? WHERE serial = ?",
      [tileX, tileY, serial]
    );
  }

  static inline function rowOf(r:Dynamic):MobileRow return {
    serial: (r.serial : Int),
    accountId: r.account_id == null ? null : (r.account_id : Int),
    name: (r.name : String),
    zoneId: (r.zone_id : Int),
    tileX: (r.tile_x : Int),
    tileY: (r.tile_y : Int)
  };
}
