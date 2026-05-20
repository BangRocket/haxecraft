package server.db;

import server.zone.SerialCounter;

class SerialCounterDal implements SerialCounter {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function loadMobileNext():Int {
    var rows = db.query("SELECT mobile_next FROM serial_counters WHERE id = 1", []);
    if (rows.length == 0) throw "serial_counters row missing — migration 0005 not applied?";
    return (rows[0].mobile_next : Int);
  }

  public function loadItemNext():Int {
    var rows = db.query("SELECT item_next FROM serial_counters WHERE id = 1", []);
    if (rows.length == 0) throw "serial_counters row missing — migration 0005 not applied?";
    return (rows[0].item_next : Int);
  }

  public function storeMobileNext(v:Int):Void {
    db.exec("UPDATE serial_counters SET mobile_next = ? WHERE id = 1", [v]);
  }

  public function storeItemNext(v:Int):Void {
    db.exec("UPDATE serial_counters SET item_next = ? WHERE id = 1", [v]);
  }
}
