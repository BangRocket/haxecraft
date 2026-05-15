package server;

import server.net.TcpServer;
import server.net.MessageDispatcher;
import server.auth.HelloHandler;
import shared.Constants;
import shared.proto.MsgType;

class Main {
  public static function main() {
    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    var dispatcher = new MessageDispatcher();
    dispatcher.register(MsgType.HELLO, HelloHandler.handle);

    while (true) {
      srv.tickAccept();
      var i = 0;
      while (i < srv.connections.length) {
        var c = srv.connections[i];
        var frames = c.pollFrames();
        for (f in frames) dispatcher.dispatch(c, f.msgType, f.payload);
        if (!c.alive) {
          c.close();
          srv.connections.splice(i, 1);
        } else {
          i++;
        }
      }
      Sys.sleep(0.01);
    }
  }
}
