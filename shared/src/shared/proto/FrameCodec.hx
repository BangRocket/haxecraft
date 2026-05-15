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
}
