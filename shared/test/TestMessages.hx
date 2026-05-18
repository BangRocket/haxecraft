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
import shared.proto.MsgChat;

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

  function testMoveIntent() {
    var m = new shared.proto.MsgMoveIntent();
    m.dir = 2;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgMoveIntent.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(2, m2.dir);
  }

  function testEntityMove() {
    var m = new shared.proto.MsgEntityMove();
    m.entityId = 42;
    m.fromX = 10; m.fromY = 20;
    m.toX = 11; m.toY = 20;
    m.durationMs = 200;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgEntityMove.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(42, m2.entityId);
    Assert.equals(10, m2.fromX);
    Assert.equals(11, m2.toX);
    Assert.equals(200, m2.durationMs);
  }

  function testGroundItemSpawn() {
    var m = new shared.proto.MsgGroundItemSpawn();
    m.worldItemId = 5;
    m.itemTypeId = 1;
    m.count = 3;
    m.tileX = 100;
    m.tileY = 200;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgGroundItemSpawn.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(5, m2.worldItemId);
    Assert.equals(1, m2.itemTypeId);
    Assert.equals(3, m2.count);
    Assert.equals(100, m2.tileX);
    Assert.equals(200, m2.tileY);
  }

  function testWorldObjectSpawn() {
    var m = new shared.proto.MsgWorldObjectSpawn();
    m.objectId = 2;
    m.objectTypeId = 64;
    m.tileX = 514;
    m.tileY = 513;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgWorldObjectSpawn.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(2, m2.objectId);
    Assert.equals(64, m2.objectTypeId);
    Assert.equals(514, m2.tileX);
    Assert.equals(513, m2.tileY);
  }

  function testChat() {
    var m = new MsgChat();
    m.channel = 2;
    m.senderName = "Bob";
    m.text = "waves.";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgChat.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(2, m2.channel);
    Assert.equals("Bob", m2.senderName);
    Assert.equals("waves.", m2.text);
  }

  function testInventory() {
    var m = new shared.proto.MsgInventory();
    m.activeSlot = 2;
    m.slots = [{ itemTypeId: 1, count: 7 }, { itemTypeId: 54, count: 1 }];
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgInventory.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(2, m2.activeSlot);
    Assert.equals(2, m2.slots.length);
    Assert.equals(1, m2.slots[0].itemTypeId);
    Assert.equals(7, m2.slots[0].count);
    Assert.equals(54, m2.slots[1].itemTypeId);
    Assert.equals(1, m2.slots[1].count);
  }

  function testGroundItemDespawn() {
    var m = new shared.proto.MsgGroundItemDespawn();
    m.worldItemId = 17;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgGroundItemDespawn.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(17, m2.worldItemId);
  }

  function testSelectActiveItem() {
    var m = new shared.proto.MsgSelectActiveItem();
    m.slot = 4;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgSelectActiveItem.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(4, m2.slot);
  }

  function testUseItemOnTile() {
    var m = new shared.proto.MsgUseItemOnTile();
    m.tileX = 480;
    m.tileY = 543;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgUseItemOnTile.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(480, m2.tileX);
    Assert.equals(543, m2.tileY);
  }

  function testTileChange() {
    var m = new shared.proto.MsgTileChange();
    m.tileX = 100;
    m.tileY = 200;
    m.tileType = 16;
    m.data = 3;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgTileChange.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(100, m2.tileX);
    Assert.equals(200, m2.tileY);
    Assert.equals(16, m2.tileType);
    Assert.equals(3, m2.data);
  }

  function testCraft() {
    var m = new shared.proto.MsgCraft();
    m.recipeId = 12;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgCraft.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(12, m2.recipeId);
  }

  function testPlaceFurniture() {
    var m = new shared.proto.MsgPlaceFurniture();
    m.tileX = 480;
    m.tileY = 544;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = shared.proto.MsgPlaceFurniture.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(480, m2.tileX);
    Assert.equals(544, m2.tileY);
  }
}
