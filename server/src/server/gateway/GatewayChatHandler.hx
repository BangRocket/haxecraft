package server.gateway;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgChat;
import shared.proto.ChatChannel;
import shared.proto.MsgType;

/** Broadcasts GLOBAL chat to every logged-in gateway connection. */
class GatewayChatHandler {
  static inline var MAX_TEXT = 200;

  var players:GatewayPlayers;

  public function new(players:GatewayPlayers) {
    this.players = players;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var m = MsgChat.deserialize(new BytesInput(payload));
    if (m.channel != (ChatChannel.GLOBAL : Int)) return;   // gateway only routes GLOBAL

    var name = players.nameOf(conn.id);
    if (name == null) return;                              // not logged in — drop

    m.senderName = name;
    if (m.text.length > MAX_TEXT) m.text = m.text.substr(0, MAX_TEXT);

    var out = new BytesOutput(); m.serialize(out);
    var bytes = out.getBytes();
    for (p in players.all()) {
      if (p.conn.alive) p.conn.sendFrame(MsgType.CHAT, bytes);
    }
  }
}
