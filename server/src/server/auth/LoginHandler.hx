package server.auth;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import server.db.AccountDal;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgType;
import shared.security.PasswordHash;

class LoginHandler {
  var dal:AccountDal;
  var sessions:SessionStore;

  public function new(dal:AccountDal, sessions:SessionStore) {
    this.dal = dal;
    this.sessions = sessions;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var login = MsgLogin.deserialize(new BytesInput(payload));
    var ack = new MsgLoginAck();

    var acct = dal.findByUsername(login.username);
    if (acct == null || !PasswordHash.verify(login.password, acct.passwordHash)) {
      ack.success = false;
      ack.sessionToken = "";
      ack.errorMsg = "invalid username or password";
      Sys.println('[server] conn ${conn.id} login FAIL user=${login.username}');
    } else {
      ack.success = true;
      ack.sessionToken = sessions.mint(acct.id);
      ack.errorMsg = "";
      Sys.println('[server] conn ${conn.id} login OK user=${login.username} acct=${acct.id}');
    }

    var out = new BytesOutput();
    ack.serialize(out);
    conn.sendFrame(MsgType.LOGIN_ACK, out.getBytes());
  }
}
