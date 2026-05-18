package server.db;

/** Persists server-side tile edits (chopped trees, mined rock, planted
    crops) so a zone's world survives a process restart. */
class ZoneTileDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function loadOverrides(zoneId:Int = 1):Array<{x:Int, y:Int, tileType:Int, data:Int}> {
    var rows = db.query(
      "SELECT x, y, tile_type, data FROM zone_tile_overrides WHERE zone_id = ?",
      [zoneId]
    );
    var out:Array<{x:Int, y:Int, tileType:Int, data:Int}> = [];
    for (r in rows) {
      out.push({ x: (r.x : Int), y: (r.y : Int),
                 tileType: (r.tile_type : Int), data: (r.data : Int) });
    }
    return out;
  }

  public function upsert(x:Int, y:Int, tileType:Int, data:Int, zoneId:Int = 1):Void {
    db.exec(
      "INSERT INTO zone_tile_overrides (zone_id, x, y, tile_type, data) VALUES (?, ?, ?, ?, ?) "
      + "ON DUPLICATE KEY UPDATE tile_type = VALUES(tile_type), data = VALUES(data)",
      [zoneId, x, y, tileType, data]
    );
  }
}
