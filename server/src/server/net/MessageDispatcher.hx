package server.net;

import haxe.io.Bytes;

typedef Handler = (conn:ClientConnection, payload:Bytes) -> Void;

class MessageDispatcher {
  var handlers:Map<Int, Handler> = new Map();

  public function new() {}

  public function register(msgType:Int, handler:Handler):Void {
    handlers.set(msgType, handler);
  }

  public function dispatch(conn:ClientConnection, msgType:Int, payload:Bytes):Void {
    var h = handlers.get(msgType);
    if (h == null) {
      Sys.println('[server] conn ${conn.id}: no handler for msgType=$msgType');
      conn.close();
      return;
    }
    try {
      h(conn, payload);
    } catch (e:Dynamic) {
      Sys.println('[server] conn ${conn.id}: handler threw for msgType=$msgType: $e');
      conn.close();
    }
  }
}
