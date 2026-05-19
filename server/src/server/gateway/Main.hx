package server.gateway;

import server.net.TcpServer;
import server.net.MessageDispatcher;
import server.auth.HelloHandler;
import server.db.DbClient;
import server.db.AccountDal;
import server.db.CharacterDal;
import server.gateway.LoginHandler;
import server.auth.SessionStore;
import shared.Constants;
import shared.proto.MsgType;

class Main {
  static var shutdownRequested:Bool = false;

  public static function main() {
    sys.thread.Thread.create(function() {
      try {
        while (true) Sys.stdin().readByte();
      } catch (_:Dynamic) {
        shutdownRequested = true;
      }
    });

    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    var dispatcher = new MessageDispatcher();
    dispatcher.register(MsgType.HELLO, HelloHandler.handle);

    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var accountDal = new AccountDal(db);
    var characterDal = new CharacterDal(db);
    var sessions = new SessionStore();
    var players = new GatewayPlayers();
    var loginHandler = new LoginHandler(accountDal, characterDal, sessions, players);
    dispatcher.register(MsgType.LOGIN, loginHandler.handle);
    var chatHandler = new GatewayChatHandler(players);
    dispatcher.register(MsgType.CHAT, chatHandler.handle);

    while (!shutdownRequested) {
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

    Sys.println('[gateway] shutdown requested; closing sockets and db');
    srv.close();
    try db.close() catch (_:Dynamic) {}
    Sys.println('[gateway] shutdown complete');
  }
}
