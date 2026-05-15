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

  function testZoneHandoff() {
    var m = new shared.proto.MsgZoneHandoff();
    m.zoneHost = "127.0.0.1";
    m.zonePort = 7778;
    m.handoffToken = "42|7|9999999999|abc123";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgZoneHandoff.deserialize(new BytesInput(out.getBytes()));
    Assert.equals("127.0.0.1", m2.zoneHost);
    Assert.equals(7778, m2.zonePort);
    Assert.equals("42|7|9999999999|abc123", m2.handoffToken);
  }

  function testEnterZone() {
    var m = new shared.proto.MsgEnterZone();
    m.handoffToken = "tok-xyz";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgEnterZone.deserialize(new BytesInput(out.getBytes()));
    Assert.equals("tok-xyz", m2.handoffToken);
  }

  function testEnterZoneAck() {
    var m = new shared.proto.MsgEnterZoneAck();
    m.success = true;
    m.entityId = 99;
    m.tileX = 512;
    m.tileY = 512;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgEnterZoneAck.deserialize(new BytesInput(out.getBytes()));
    Assert.isTrue(m2.success);
    Assert.equals(99, m2.entityId);
    Assert.equals(512, m2.tileX);
    Assert.equals(512, m2.tileY);
  }

  function testEntitySpawn() {
    var m = new shared.proto.MsgEntitySpawn();
    m.entityId = 42;
    m.name = "alice";
    m.tileX = 10;
    m.tileY = 20;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgEntitySpawn.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(42, m2.entityId);
    Assert.equals("alice", m2.name);
    Assert.equals(10, m2.tileX);
    Assert.equals(20, m2.tileY);
  }

  function testEntityDespawn() {
    var m = new shared.proto.MsgEntityDespawn();
    m.entityId = 7;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgEntityDespawn.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(7, m2.entityId);
  }
}
