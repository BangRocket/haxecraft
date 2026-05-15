package server.zone;

import server.net.TcpServer;
import server.net.MessageDispatcher;
import server.db.DbClient;
import server.db.CharacterDal;
import shared.Constants;
import shared.proto.MsgType;

class Main {
  public static function main() {
    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var characterDal = new CharacterDal(db);

    Sys.println("[zone] loading map...");
    var map = MapLoader.loadFromFile("res/maps/starter.tmx");
    Sys.println('[zone] map loaded: ${map.width}x${map.height}');

    var enterHandler = new EnterZoneHandler(characterDal);

    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.ZONE_PORT);
    var dispatcher = new MessageDispatcher();
    dispatcher.register(MsgType.ENTER_ZONE, enterHandler.handle);

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
