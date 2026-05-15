package server.db;

typedef Character = {
  id:Int,
  accountId:Int,
  name:String,
  zoneId:Int,
  tileX:Int,
  tileY:Int
};

class CharacterDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function findByAccountId(accountId:Int):Null<Character> {
    var rows = db.query(
      "SELECT id, account_id, name, zone_id, tile_x, tile_y FROM characters WHERE account_id = ? LIMIT 1",
      [accountId]
    );
    if (rows.length == 0) return null;
    var r = rows[0];
    return {
      id: (r.id : Int),
      accountId: (r.account_id : Int),
      name: (r.name : String),
      zoneId: (r.zone_id : Int),
      tileX: (r.tile_x : Int),
      tileY: (r.tile_y : Int)
    };
  }

  public function autoCreate(accountId:Int, name:String):Int {
    db.exec(
      "INSERT INTO characters (account_id, name) VALUES (?, ?)",
      [accountId, name]
    );
    return db.lastInsertId();
  }

  public function savePosition(characterId:Int, tileX:Int, tileY:Int):Void {
    db.exec(
      "UPDATE characters SET tile_x = ?, tile_y = ? WHERE id = ?",
      [tileX, tileY, characterId]
    );
  }
}
