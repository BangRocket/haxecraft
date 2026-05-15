package server.net;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesBuffer;
import shared.Constants;

class FrameBuffer {
  var buf:Bytes = Bytes.alloc(0);

  public function new() {}

  public function feed(chunk:Bytes):Void {
    if (chunk == null || chunk.length == 0) return;
    var combined = new BytesBuffer();
    combined.add(buf);
    combined.add(chunk);
    buf = combined.getBytes();
  }

  public function drainCompleteFrames():Array<{msgType:Int, payload:Bytes}> {
    var out:Array<{msgType:Int, payload:Bytes}> = [];
    while (true) {
      if (buf.length < 2) break;
      var declaredLen = buf.getUInt16(0);
      if (declaredLen < 1 || declaredLen > Constants.MAX_FRAME_SIZE) {
        throw "FrameBuffer: invalid declared frame length " + declaredLen;
      }
      var totalLen = 2 + declaredLen;
      if (buf.length < totalLen) break;
      var frameBytes = buf.sub(0, totalLen);
      var inp = new BytesInput(frameBytes);
      out.push(shared.proto.FrameCodec.readFrame(inp));
      buf = buf.sub(totalLen, buf.length - totalLen);
    }
    return out;
  }
}
