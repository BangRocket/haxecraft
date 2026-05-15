package server.net;

import sys.net.Socket;
import sys.net.Host;

class TcpServer {
  var listenSocket:Socket;
  var nextConnId:Int = 1;
  public var connections:Array<ClientConnection> = [];

  public function new(host:String, port:Int) {
    listenSocket = new Socket();
    listenSocket.bind(new Host(host), port);
    listenSocket.listen(32);
    listenSocket.setBlocking(false);
    Sys.println('[server] listening on $host:$port');
  }

  /** Non-blocking accept. Returns new connections accepted this tick. */
  public function tickAccept():Array<ClientConnection> {
    var fresh:Array<ClientConnection> = [];
    while (true) {
      try {
        var s = listenSocket.accept();
        if (s == null) break;
        s.setBlocking(false);
        var conn = new ClientConnection(s, nextConnId++);
        connections.push(conn);
        fresh.push(conn);
        Sys.println('[server] accepted conn id=${conn.id}');
      } catch (_:Dynamic) {
        // No pending connection; non-blocking would-block — stop polling.
        break;
      }
    }
    return fresh;
  }

  public function close():Void {
    for (c in connections) c.close();
    try listenSocket.close() catch (_:Dynamic) {}
  }
}
