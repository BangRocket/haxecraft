package;

import utest.Assert;
import utest.Test;
import sys.net.Socket;
import sys.net.Host;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.db.DbClient;
import server.db.AccountDal;
import shared.Constants;
import shared.proto.FrameCodec;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgType;
import shared.security.PasswordHash;

class TestLoginFlow extends Test {
  var db:DbClient;
  var dal:AccountDal;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    dal = new AccountDal(db);
    db.exec("DELETE FROM items WHERE parent_serial IN (SELECT serial FROM mobiles WHERE name = ?)", ["test_login_user"]);
    db.exec("DELETE FROM mobiles WHERE name = ?", ["test_login_user"]);
    db.exec("DELETE FROM accounts WHERE username = ?", ["test_login_user"]);
    dal.create("test_login_user", PasswordHash.hash("test_login_pw"));
  }

  function teardownClass() {
    db.exec("DELETE FROM items WHERE parent_serial IN (SELECT serial FROM mobiles WHERE name = ?)", ["test_login_user"]);
    db.exec("DELETE FROM mobiles WHERE name = ?", ["test_login_user"]);
    db.exec("DELETE FROM accounts WHERE username = ?", ["test_login_user"]);
    db.close();
  }

  // PRECONDITION: server running on localhost:7777.
  // run-integration.sh boots the server before invoking this test.

  function testHelloAndLoginRoundTrip() {
    var s = new Socket();
    s.connect(new Host("127.0.0.1"), Constants.DEFAULT_SERVER_PORT);

    // --- Hello ---
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "integration-test";
    var helloPayload = new BytesOutput();
    hello.serialize(helloPayload);
    var helloFrame = new BytesOutput();
    FrameCodec.writeFrame(helloFrame, MsgType.HELLO, helloPayload.getBytes());
    var hb = helloFrame.getBytes();
    s.output.writeBytes(hb, 0, hb.length);

    var ackFrame = FrameCodec.readFrame(s.input);
    Assert.equals((MsgType.HELLO_ACK : Int), ackFrame.msgType);
    var helloAck = MsgHelloAck.deserialize(new BytesInput(ackFrame.payload));
    Assert.isTrue(helloAck.ok);

    // --- Login (correct password) ---
    var login = new MsgLogin();
    login.username = "test_login_user";
    login.password = "test_login_pw";
    var loginPayload = new BytesOutput();
    login.serialize(loginPayload);
    var loginFrame = new BytesOutput();
    FrameCodec.writeFrame(loginFrame, MsgType.LOGIN, loginPayload.getBytes());
    var lb = loginFrame.getBytes();
    s.output.writeBytes(lb, 0, lb.length);

    var loginAckFrame = FrameCodec.readFrame(s.input);
    Assert.equals((MsgType.LOGIN_ACK : Int), loginAckFrame.msgType);
    var loginAck = MsgLoginAck.deserialize(new BytesInput(loginAckFrame.payload));
    Assert.isTrue(loginAck.success);
    Assert.isTrue(loginAck.sessionToken.length >= 16);
    Assert.equals("", loginAck.errorMsg);

    // After successful login, gateway sends a ZoneHandoff on the same connection.
    var handoffFrame = FrameCodec.readFrame(s.input);
    Assert.equals((shared.proto.MsgType.ZONE_HANDOFF : Int), handoffFrame.msgType);
    var handoff = shared.proto.MsgZoneHandoff.deserialize(new BytesInput(handoffFrame.payload));
    Assert.equals("127.0.0.1", handoff.zoneHost);
    Assert.equals(7778, handoff.zonePort);
    Assert.isTrue(handoff.handoffToken.length > 0);

    var parsed = shared.security.HandoffToken.verify(handoff.handoffToken);
    Assert.notNull(parsed);

    s.close();
  }

  function testLoginWithBadPasswordFails() {
    var s = new Socket();
    s.connect(new Host("127.0.0.1"), Constants.DEFAULT_SERVER_PORT);

    // Hello first
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "integration-test";
    var hp = new BytesOutput(); hello.serialize(hp);
    var hf = new BytesOutput(); FrameCodec.writeFrame(hf, MsgType.HELLO, hp.getBytes());
    var hb = hf.getBytes(); s.output.writeBytes(hb, 0, hb.length);
    FrameCodec.readFrame(s.input);  // consume HelloAck

    var login = new MsgLogin();
    login.username = "test_login_user";
    login.password = "WRONG";
    var lp = new BytesOutput(); login.serialize(lp);
    var lf = new BytesOutput(); FrameCodec.writeFrame(lf, MsgType.LOGIN, lp.getBytes());
    var lb = lf.getBytes(); s.output.writeBytes(lb, 0, lb.length);

    var ackFrame = FrameCodec.readFrame(s.input);
    var ack = MsgLoginAck.deserialize(new BytesInput(ackFrame.payload));
    Assert.isFalse(ack.success);
    Assert.equals("", ack.sessionToken);
    Assert.isTrue(ack.errorMsg.length > 0);

    s.close();
  }
}
