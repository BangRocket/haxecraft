package;

import utest.Test;
import utest.Assert;
import client.ui.ChatCommandParser;
import shared.proto.ChatChannel;

class TestChatCommandParser extends Test {
  function testPlainTextIsSay() {
    var r = ChatCommandParser.parse("hello there");
    Assert.equals((ChatChannel.SAY : Int), r.channel);
    Assert.equals("hello there", r.text);
  }

  function testGlobalCommand() {
    var r = ChatCommandParser.parse("/g anyone online?");
    Assert.equals((ChatChannel.GLOBAL : Int), r.channel);
    Assert.equals("anyone online?", r.text);
  }

  function testMeEmote() {
    var r = ChatCommandParser.parse("/me ponders the void");
    Assert.equals((ChatChannel.EMOTE : Int), r.channel);
    Assert.equals("ponders the void", r.text);
  }

  function testCannedEmote() {
    var r = ChatCommandParser.parse("/wave");
    Assert.equals((ChatChannel.EMOTE : Int), r.channel);
    Assert.equals("waves.", r.text);
  }

  function testUnknownSlashIsSay() {
    var r = ChatCommandParser.parse("/notacommand hi");
    Assert.equals((ChatChannel.SAY : Int), r.channel);
    Assert.equals("/notacommand hi", r.text);
  }
}
