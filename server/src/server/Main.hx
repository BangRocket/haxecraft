package server;

import server.net.TcpServer;
import shared.Constants;

class Main {
  public static function main() {
    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    while (true) {
      srv.tickAccept();
      Sys.sleep(0.01);
    }
  }
}
