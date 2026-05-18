package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;
import shared.proto.MsgType;
import shared.proto.MsgChat;
import shared.proto.ChatChannel;
import haxe.io.BytesInput;
import HeadlessClient;

class TestZoneChat extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var userA:String = "test_chat_a";
  var userB:String = "test_chat_b";
  var pw:String = "test_pw";

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    accountDal = new AccountDal(db);
    for (u in [userA, userB]) {
      db.exec("DELETE FROM characters WHERE name = ?", [u]);
      db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      accountDal.create(u, PasswordHash.hash(pw));
    }
  }

  function teardownClass() {
    if (db != null) {
      for (u in [userA, userB]) {
        db.exec("DELETE FROM characters WHERE name = ?", [u]);
        db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      }
      db.close();
    }
  }

  // PRECONDITION: gateway + zone running on 127.0.0.1:7777/7778.

  function plant(name:String, x:Int, y:Int):Void {
    db.exec("UPDATE characters SET tile_x = ?, tile_y = ? WHERE name = ?", [x, y, name]);
  }

  function loginClient(user:String):HeadlessClient {
    var c = new HeadlessClient();
    c.connectGateway();
    Assert.isTrue(c.login(user, pw));
    return c;
  }

  // True if any CHAT frame in `frames` has the given channel and text.
  static function sawChat(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>, channel:Int, text:String):Bool {
    for (f in frames) if (f.msgType == (MsgType.CHAT : Int)) {
      var m = MsgChat.deserialize(new BytesInput(f.payload));
      if (m.channel == channel && m.text == text) return true;
    }
    return false;
  }

  function testNearbySayAndEmoteReach() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 306, 512);              // ~6 tiles apart — inside interest range
    cA.enterZone();
    cB.enterZone();
    Sys.sleep(0.4);                      // let interest ticks register both

    cA.sendChat((ChatChannel.SAY : Int), "hello bob");
    Assert.isTrue(sawChat(cB.drainFrames(0.6), (ChatChannel.SAY : Int), "hello bob"),
      "nearby B should receive A's say");

    cA.sendChat((ChatChannel.EMOTE : Int), "waves.");
    Assert.isTrue(sawChat(cB.drainFrames(0.6), (ChatChannel.EMOTE : Int), "waves."),
      "nearby B should receive A's emote");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }

  function testDistantSayDoesNotReachButGlobalDoes() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 800, 512);              // 500 tiles apart — far beyond interest range
    cA.enterZone();
    cB.enterZone();
    Sys.sleep(0.4);

    cA.sendChat((ChatChannel.SAY : Int), "psst");
    Assert.isFalse(sawChat(cB.drainFrames(0.6), (ChatChannel.SAY : Int), "psst"),
      "distant B must not receive A's say");

    cA.sendChat((ChatChannel.GLOBAL : Int), "anyone there");
    Assert.isTrue(sawChat(cB.drainGatewayFrames(0.6), (ChatChannel.GLOBAL : Int), "anyone there"),
      "distant B should receive A's global chat");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }
}
