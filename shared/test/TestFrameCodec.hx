package;

import utest.Assert;
import utest.Test;
import haxe.io.BytesOutput;
import haxe.io.Bytes;
import shared.proto.FrameCodec;

class TestFrameCodec extends Test {
  function testWriteFrameEmptyPayload() {
    var out = new BytesOutput();
    var payload = Bytes.alloc(0);
    FrameCodec.writeFrame(out, 42, payload);
    var result = out.getBytes();
    // length=1 (just msgType byte), msgType=42, no payload
    Assert.equals(3, result.length);
    Assert.equals(1, result.getUInt16(0));   // length (LE)
    Assert.equals(42, result.get(2));         // msgType
  }

  function testWriteFrameWithPayload() {
    var out = new BytesOutput();
    var payload = Bytes.ofString("hi");
    FrameCodec.writeFrame(out, 7, payload);
    var result = out.getBytes();
    Assert.equals(5, result.length);
    Assert.equals(3, result.getUInt16(0));   // 1 (msgType) + 2 (payload)
    Assert.equals(7, result.get(2));
    Assert.equals(0x68, result.get(3));      // 'h'
    Assert.equals(0x69, result.get(4));      // 'i'
  }

  function testWriteFrameRejectsOversizedPayload() {
    var out = new BytesOutput();
    var payload = Bytes.alloc(70000);
    Assert.raises(() -> FrameCodec.writeFrame(out, 1, payload));
  }

  function testReadFrameRoundtrip() {
    var out = new BytesOutput();
    var payload = Bytes.ofString("hello");
    FrameCodec.writeFrame(out, 3, payload);
    var inp = new haxe.io.BytesInput(out.getBytes());
    var frame = FrameCodec.readFrame(inp);
    Assert.equals(3, frame.msgType);
    Assert.equals("hello", frame.payload.toString());
  }

  function testReadFrameRejectsOversizedHeader() {
    var b = Bytes.alloc(3);
    b.setUInt16(0, 70000);  // claimed length, exceeds MAX_FRAME_SIZE
    b.set(2, 1);
    var inp = new haxe.io.BytesInput(b);
    Assert.raises(() -> FrameCodec.readFrame(inp));
  }
}
