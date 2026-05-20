package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgChat;
import shared.proto.MsgType;

/** Routes SAY / EMOTE chat to the sender and everyone in their interest range. */
class ChatHandler {
  static inline var MAX_TEXT = 200;

  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;
  var interest:InterestManager;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler, interest:InterestManager) {
    this.sim = sim;
    this.enterHandler = enterHandler;
    this.interest = interest;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return;                       // not in the zone — drop
    var sender = sim.mobileBySerial(entId);
    if (sender == null) return;

    var msg = MsgChat.deserialize(new BytesInput(payload));
    msg.senderName = sender.name;                    // authoritative — never trust the client field
    if (msg.text.length > MAX_TEXT) msg.text = msg.text.substr(0, MAX_TEXT);

    var out = new BytesOutput(); msg.serialize(out);
    var bytes = out.getBytes();

    if (sender.conn != null && sender.conn.alive) {
      sender.conn.sendFrame(MsgType.CHAT, bytes);
    }
    for (obsId in interest.observersOf(entId)) {
      var obs = sim.mobileBySerial(obsId);
      if (obs != null && obs.conn != null && obs.conn.alive) {
        obs.conn.sendFrame(MsgType.CHAT, bytes);
      }
    }
  }
}
