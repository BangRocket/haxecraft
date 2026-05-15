package shared.proto;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Input;
import shared.Constants;

class FrameCodec {
  public static function writeFrame(out:BytesOutput, msgType:Int, payload:Bytes):Void {
    var len = payload.length + 1;
    if (len > Constants.MAX_FRAME_SIZE) {
      throw "frame too large: " + len + " bytes (max " + Constants.MAX_FRAME_SIZE + ")";
    }
    out.writeUInt16(len);
    out.writeByte(msgType);
    if (payload.length > 0) out.writeBytes(payload, 0, payload.length);
  }

  public static function readFrame(inp:Input):{msgType:Int, payload:Bytes} {
    var len = inp.readUInt16();
    if (len < 1 || len > Constants.MAX_FRAME_SIZE) {
      throw "invalid frame length: " + len;
    }
    var msgType = inp.readByte();
    var payloadLen = len - 1;
    var payload = payloadLen > 0 ? inp.read(payloadLen) : Bytes.alloc(0);
    return { msgType: msgType, payload: payload };
  }
}
