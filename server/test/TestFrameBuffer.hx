package;

import utest.Assert;
import utest.Test;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import shared.proto.FrameCodec;
import shared.proto.FrameBuffer;

class TestFrameBuffer extends Test {
  function testCompleteFrameYields() {
    var fb = new FrameBuffer();
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, 7, Bytes.ofString("hi"));
    fb.feed(out.getBytes());
    var frames = fb.drainCompleteFrames();
    Assert.equals(1, frames.length);
    Assert.equals(7, frames[0].msgType);
  }

  function testPartialFrameWaits() {
    var fb = new FrameBuffer();
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, 7, Bytes.ofString("hi"));
    var full = out.getBytes();
    fb.feed(full.sub(0, 2));  // only the length bytes
    Assert.equals(0, fb.drainCompleteFrames().length);
    fb.feed(full.sub(2, full.length - 2));
    var frames = fb.drainCompleteFrames();
    Assert.equals(1, frames.length);
  }

  function testTwoBackToBackFrames() {
    var fb = new FrameBuffer();
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, 1, Bytes.ofString("a"));
    FrameCodec.writeFrame(out, 2, Bytes.ofString("bb"));
    fb.feed(out.getBytes());
    var frames = fb.drainCompleteFrames();
    Assert.equals(2, frames.length);
    Assert.equals(1, frames[0].msgType);
    Assert.equals(2, frames[1].msgType);
  }
}
