package server.auth;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.Constants;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgType;

class HelloHandler {
  public static function handle(conn:ClientConnection, payload:Bytes):Void {
    var hello = MsgHello.deserialize(new BytesInput(payload));
    Sys.println('[server] conn ${conn.id} Hello version=${hello.protocolVersion} build=${hello.buildHash}');

    var ack = new MsgHelloAck();
    if (hello.protocolVersion != Constants.PROTOCOL_VERSION) {
      ack.ok = false;
      ack.reason = 'protocol mismatch (server=${Constants.PROTOCOL_VERSION} client=${hello.protocolVersion})';
    } else {
      ack.ok = true;
      ack.reason = "";
    }

    var out = new BytesOutput();
    ack.serialize(out);
    conn.sendFrame(MsgType.HELLO_ACK, out.getBytes());

    if (!ack.ok) conn.close();
  }
}
