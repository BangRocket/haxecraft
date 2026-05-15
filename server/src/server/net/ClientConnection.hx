package server.net;

import sys.net.Socket;

class ClientConnection {
  public var socket:Socket;
  public var id:Int;

  public function new(socket:Socket, id:Int) {
    this.socket = socket;
    this.id = id;
  }

  public function close():Void {
    try socket.close() catch (_:Dynamic) {}
  }
}
