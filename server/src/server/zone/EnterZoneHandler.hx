package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import server.db.CharacterDal;
import shared.proto.MsgEnterZone;
import shared.proto.MsgEnterZoneAck;
import shared.proto.MsgType;
import shared.security.HandoffToken;

class EnterZoneHandler {
  var characterDal:CharacterDal;

  public function new(characterDal:CharacterDal) {
    this.characterDal = characterDal;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var req = MsgEnterZone.deserialize(new BytesInput(payload));
    var ack = new MsgEnterZoneAck();

    var parsed = HandoffToken.verify(req.handoffToken);
    if (parsed == null) {
      ack.success = false;
      ack.errorMsg = "invalid or expired handoff token";
      Sys.println('[zone] conn ${conn.id} EnterZone REJECT (bad token)');
      sendAck(conn, ack);
      conn.close();
      return;
    }

    var ch = characterDal.findByAccountId(parsed.accountId);
    if (ch == null || ch.id != parsed.characterId) {
      ack.success = false;
      ack.errorMsg = "character not found";
      Sys.println('[zone] conn ${conn.id} EnterZone REJECT (char missing acct=${parsed.accountId} char=${parsed.characterId})');
      sendAck(conn, ack);
      conn.close();
      return;
    }

    ack.success = true;
    ack.entityId = ch.id;
    ack.tileX = ch.tileX;
    ack.tileY = ch.tileY;
    Sys.println('[zone] conn ${conn.id} EnterZone OK char=${ch.id} pos=(${ch.tileX},${ch.tileY})');
    sendAck(conn, ack);
    // Spawn into the simulator — wired in Task 14/15.
  }

  static function sendAck(conn:ClientConnection, ack:MsgEnterZoneAck):Void {
    var out = new BytesOutput(); ack.serialize(out);
    conn.sendFrame(MsgType.ENTER_ZONE_ACK, out.getBytes());
  }
}
