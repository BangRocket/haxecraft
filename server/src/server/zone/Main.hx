package server.zone;

import server.net.TcpServer;
import server.net.MessageDispatcher;
import shared.Constants;

class Main {
  public static function main() {
    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.ZONE_PORT);
    var dispatcher = new MessageDispatcher();

    // Tick loop wiring — full ZoneSimulator integration arrives in Task 14.
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
