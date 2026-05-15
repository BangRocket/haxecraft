package client.net;

import haxe.io.Bytes;

typedef ClientHandler = (payload:Bytes) -> Void;

class ClientDispatcher {
  var handlers:Map<Int, ClientHandler> = new Map();

  public function new() {}

  public function on(msgType:Int, handler:ClientHandler):Void {
    handlers.set(msgType, handler);
  }

  public function dispatch(msgType:Int, payload:Bytes):Void {
    var h = handlers.get(msgType);
    if (h != null) h(payload);
    else trace('[client] no handler for msgType=$msgType');
  }
}
