package client.net;

import sys.net.Socket;
import sys.net.Host;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import shared.proto.FrameBuffer;
import shared.proto.FrameCodec;

enum ConnectionState {
  DISCONNECTED;
  CONNECTING;
  CONNECTED;
  CLOSED;
}

class TcpConnection {
  var socket:Socket;
  public var state(default, null):ConnectionState = DISCONNECTED;
  var frameBuffer:FrameBuffer = new FrameBuffer();

  public function new() {}

  public function connect(host:String, port:Int):Void {
    state = CONNECTING;
    socket = new Socket();
    try {
      socket.connect(new Host(host), port);
      socket.setBlocking(false);
      state = CONNECTED;
    } catch (e:Dynamic) {
      state = CLOSED;
      throw 'TcpConnection: connect failed: $e';
    }
  }

  public function sendFrame(msgType:Int, payload:Bytes):Void {
    if (state != CONNECTED) return;
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, msgType, payload);
    var b = out.getBytes();
    try {
      socket.output.writeBytes(b, 0, b.length);
    } catch (e:Dynamic) {
      state = CLOSED;
    }
  }

  /** Returns frames available this poll. Call once per Heaps update tick. */
  public function poll():Array<{msgType:Int, payload:Bytes}> {
    if (state != CONNECTED) return [];
    try {
      var chunk = Bytes.alloc(4096);
      var n = socket.input.readBytes(chunk, 0, chunk.length);
      if (n > 0) frameBuffer.feed(chunk.sub(0, n));
    } catch (e:haxe.io.Eof) {
      state = CLOSED;
      return [];
    } catch (e:Dynamic) {
      // would-block; ignore
    }
    try {
      return frameBuffer.drainCompleteFrames();
    } catch (e:Dynamic) {
      state = CLOSED;
      return [];
    }
  }

  public function close():Void {
    state = CLOSED;
    try socket.close() catch (_:Dynamic) {}
  }
}
