package server.db;

typedef ItemRow = {
  serial:Int,
  itemTypeId:Int,
  count:Int,
  parentSerial:Null<Int>,
  zoneId:Null<Int>,
  tileX:Null<Int>,
  tileY:Null<Int>,
  slot:Null<Int>
};

class ItemDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function insertWorld(serial:Int, itemTypeId:Int, count:Int,
                              zoneId:Int, tileX:Int, tileY:Int):Void {
    db.exec(
      "INSERT INTO items (serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot) VALUES (?, ?, ?, NULL, ?, ?, ?, NULL)",
      [serial, itemTypeId, count, zoneId, tileX, tileY]
    );
  }

  public function insertCarried(serial:Int, itemTypeId:Int, count:Int,
                                parentSerial:Int, slot:Int):Void {
    db.exec(
      "INSERT INTO items (serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot) VALUES (?, ?, ?, ?, NULL, NULL, NULL, ?)",
      [serial, itemTypeId, count, parentSerial, slot]
    );
  }

  public function delete(serial:Int):Void {
    db.exec("DELETE FROM items WHERE serial = ?", [serial]);
  }

  /** Update an item to the carried-by-mobile state. */
  public function reparentToMobile(serial:Int, parentSerial:Int, slot:Int):Void {
    db.exec(
      "UPDATE items SET parent_serial = ?, slot = ?, zone_id = NULL, tile_x = NULL, tile_y = NULL WHERE serial = ?",
      [parentSerial, slot, serial]
    );
  }

  public function updateCount(serial:Int, count:Int):Void {
    db.exec("UPDATE items SET count = ? WHERE serial = ?", [count, serial]);
  }

  public function loadCarriedFor(mobileSerial:Int):Array<ItemRow> {
    var rows = db.query(
      "SELECT serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot FROM items WHERE parent_serial = ? ORDER BY slot",
      [mobileSerial]
    );
    return [for (r in rows) rowOf(r)];
  }

  public function loadWorldFor(zoneId:Int):Array<ItemRow> {
    var rows = db.query(
      "SELECT serial, item_type_id, count, parent_serial, zone_id, tile_x, tile_y, slot FROM items WHERE parent_serial IS NULL AND zone_id = ?",
      [zoneId]
    );
    return [for (r in rows) rowOf(r)];
  }

  public function countForZone(zoneId:Int):Int {
    var rows = db.query("SELECT COUNT(*) AS n FROM items WHERE zone_id = ?", [zoneId]);
    return (rows[0].n : Int);
  }

  static inline function rowOf(r:Dynamic):ItemRow return {
    serial: (r.serial : Int),
    itemTypeId: (r.item_type_id : Int),
    count: (r.count : Int),
    parentSerial: r.parent_serial == null ? null : (r.parent_serial : Int),
    zoneId: r.zone_id == null ? null : (r.zone_id : Int),
    tileX: r.tile_x == null ? null : (r.tile_x : Int),
    tileY: r.tile_y == null ? null : (r.tile_y : Int),
    slot: r.slot == null ? null : (r.slot : Int)
  };
}
