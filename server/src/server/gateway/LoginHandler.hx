package server.gateway;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import server.db.AccountDal;
import server.db.CharacterDal;
import server.auth.SessionStore;
import shared.Constants;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgZoneHandoff;
import shared.proto.MsgType;
import shared.security.PasswordHash;
import shared.security.HandoffToken;

class LoginHandler {
  var accountDal:AccountDal;
  var characterDal:CharacterDal;
  var sessions:SessionStore;
  var players:GatewayPlayers;

  public function new(accountDal:AccountDal, characterDal:CharacterDal, sessions:SessionStore, players:GatewayPlayers) {
    this.accountDal = accountDal;
    this.characterDal = characterDal;
    this.sessions = sessions;
    this.players = players;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var login = MsgLogin.deserialize(new BytesInput(payload));
    var ack = new MsgLoginAck();

    var acct = accountDal.findByUsername(login.username);
    if (acct == null || !PasswordHash.verify(login.password, acct.passwordHash)) {
      ack.success = false;
      ack.sessionToken = "";
      ack.errorMsg = "invalid username or password";
      Sys.println('[gateway] conn ${conn.id} login FAIL user=${login.username}');
      var lo = new BytesOutput(); ack.serialize(lo);
      conn.sendFrame(MsgType.LOGIN_ACK, lo.getBytes());
      return;
    }

    // Auth success — ensure a character exists, then mint a handoff.
    var ch = characterDal.findByAccountId(acct.id);
    if (ch == null) {
      var newId = characterDal.autoCreate(acct.id, acct.username);
      ch = characterDal.findByAccountId(acct.id);
      Sys.println('[gateway] autocreated character id=$newId name=${acct.username}');
    }

    var token = HandoffToken.mint(acct.id, ch.id, Constants.HANDOFF_TTL_SECONDS);

    ack.success = true;
    ack.sessionToken = sessions.mint(acct.id);
    ack.errorMsg = "";
    Sys.println('[gateway] conn ${conn.id} login OK user=${login.username} acct=${acct.id} char=${ch.id}');
    players.add(conn, acct.username);
    var lo = new BytesOutput(); ack.serialize(lo);
    conn.sendFrame(MsgType.LOGIN_ACK, lo.getBytes());

    var handoff = new MsgZoneHandoff();
    handoff.zoneHost = Constants.DEFAULT_SERVER_HOST;
    handoff.zonePort = Constants.ZONE_PORT;
    handoff.handoffToken = token;
    var ho = new BytesOutput(); handoff.serialize(ho);
    conn.sendFrame(MsgType.ZONE_HANDOFF, ho.getBytes());
  }
}
