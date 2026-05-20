package server.db;

typedef MobileRow = {
  serial:Int,
  accountId:Null<Int>,
  name:String,
  zoneId:Int,
  tileX:Int,
  tileY:Int,
  str:Int,
  dex:Int,
  intel:Int,
  hp:Int,
  maxHp:Int
};

class MobileDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function findByAccountId(accountId:Int):Null<MobileRow> {
    var rows = db.query(
      "SELECT serial, account_id, name, zone_id, tile_x, tile_y, str, dex, intel, hp, max_hp FROM mobiles WHERE account_id = ? LIMIT 1",
      [accountId]
    );
    if (rows.length == 0) return null;
    return rowOf(rows[0]);
  }

  /** Insert a new mobile with an allocated serial. Combat columns get the
      DB defaults (50/50/50/50/50), matching the Mobile constructor. */
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

  public function saveStatsAndHp(serial:Int, str:Int, dex:Int, intel:Int,
                                 hp:Int, maxHp:Int):Void {
    db.exec(
      "UPDATE mobiles SET str = ?, dex = ?, intel = ?, hp = ?, max_hp = ? WHERE serial = ?",
      [str, dex, intel, hp, maxHp, serial]
    );
  }

  static inline function rowOf(r:Dynamic):MobileRow return {
    serial: (r.serial : Int),
    accountId: r.account_id == null ? null : (r.account_id : Int),
    name: (r.name : String),
    zoneId: (r.zone_id : Int),
    tileX: (r.tile_x : Int),
    tileY: (r.tile_y : Int),
    str: (r.str : Int),
    dex: (r.dex : Int),
    intel: (r.intel : Int),
    hp: (r.hp : Int),
    maxHp: (r.max_hp : Int)
  };
}
