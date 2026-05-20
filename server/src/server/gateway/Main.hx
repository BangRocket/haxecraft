package server.gateway;

import server.net.TcpServer;
import server.net.MessageDispatcher;
import server.auth.HelloHandler;
import server.db.DbClient;
import server.db.AccountDal;
import server.db.MobileDal;
import server.gateway.LoginHandler;
import server.auth.SessionStore;
import shared.Constants;
import shared.proto.MsgType;

class Main {
  public static function main() {
    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    var dispatcher = new MessageDispatcher();
    dispatcher.register(MsgType.HELLO, HelloHandler.handle);

    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var accountDal = new AccountDal(db);
    var mobileDal = new MobileDal(db);
    var sessions = new SessionStore();
    var players = new GatewayPlayers();
    var loginHandler = new LoginHandler(accountDal, mobileDal, sessions, players);
    dispatcher.register(MsgType.LOGIN, loginHandler.handle);
    var chatHandler = new GatewayChatHandler(players);
    dispatcher.register(MsgType.CHAT, chatHandler.handle);

    while (true) {
      srv.tickAccept();
      var i = 0;
      while (i < srv.connections.length) {
        var c = srv.connections[i];
        var frames = c.pollFrames();
        for (f in frames) dispatcher.dispatch(c, f.msgType, f.payload);
        if (!c.alive) {
          players.remove(c.id);
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
