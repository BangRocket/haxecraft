package;

import utest.Assert;
import utest.Test;
import haxe.io.BytesOutput;
import haxe.io.BytesInput;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgError;

class TestMessages extends Test {
  function testHello() {
    var m = new MsgHello();
    m.protocolVersion = 1;
    m.buildHash = "deadbeef";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgHello.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(1, m2.protocolVersion);
    Assert.equals("deadbeef", m2.buildHash);
  }

  function testHelloAck() {
    var m = new MsgHelloAck();
    m.ok = true;
    m.reason = "";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgHelloAck.deserialize(new BytesInput(out.getBytes()));
    Assert.isTrue(m2.ok);
    Assert.equals("", m2.reason);
  }

  function testLogin() {
    var m = new MsgLogin();
    m.username = "joshua";
    m.password = "pw";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgLogin.deserialize(new BytesInput(out.getBytes()));
    Assert.equals("joshua", m2.username);
    Assert.equals("pw", m2.password);
  }

  function testLoginAck() {
    var m = new MsgLoginAck();
    m.success = true;
    m.sessionToken = "tok-123";
    m.errorMsg = "";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgLoginAck.deserialize(new BytesInput(out.getBytes()));
    Assert.isTrue(m2.success);
    Assert.equals("tok-123", m2.sessionToken);
  }

  function testError() {
    var m = new MsgError();
    m.code = 42;
    m.message = "bad client";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgError.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(42, m2.code);
    Assert.equals("bad client", m2.message);
  }
}
