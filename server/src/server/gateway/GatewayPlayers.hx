package server.gateway;

import server.net.ClientConnection;

private typedef Entry = { conn:ClientConnection, name:String };

/** Tracks logged-in gateway connections so global chat can reach them. */
class GatewayPlayers {
  var byConn:Map<Int, Entry> = new Map();

  public function new() {}

  public function add(conn:ClientConnection, name:String):Void {
    byConn.set(conn.id, { conn: conn, name: name });
  }

  public function remove(connId:Int):Void {
    byConn.remove(connId);
  }

  public function nameOf(connId:Int):Null<String> {
    var e = byConn.get(connId);
    return e == null ? null : e.name;
  }

  public function all():Iterator<Entry> {
    return byConn.iterator();
  }
}
