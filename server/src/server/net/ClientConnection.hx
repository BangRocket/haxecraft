package server.net;

import sys.net.Socket;
import haxe.io.Bytes;

class ClientConnection {
  public var socket:Socket;
  public var id:Int;
  public var alive:Bool = true;
  public var frameBuffer:FrameBuffer = new FrameBuffer();

  public function new(socket:Socket, id:Int) {
    this.socket = socket;
    this.id = id;
  }

  /** Pull whatever bytes are available (non-blocking). Returns frames ready to dispatch. */
  public function pollFrames():Array<{msgType:Int, payload:Bytes}> {
    try {
      var chunk = Bytes.alloc(4096);
      var n = socket.input.readBytes(chunk, 0, chunk.length);
      if (n > 0) frameBuffer.feed(chunk.sub(0, n));
    } catch (e:haxe.io.Eof) {
      alive = false;
      return [];
    } catch (e:Dynamic) {
      // would-block / no data available; expected on non-blocking sockets
    }
    if (!alive) return [];
    try {
      return frameBuffer.drainCompleteFrames();
    } catch (e:Dynamic) {
      Sys.println('[server] conn ${id} protocol error: ${e} — dropping');
      alive = false;
      return [];
    }
  }

  public function sendFrame(msgType:Int, payload:Bytes):Void {
    if (!alive) return;
    try {
      var out = new haxe.io.BytesOutput();
      shared.proto.FrameCodec.writeFrame(out, msgType, payload);
      var bytes = out.getBytes();
      socket.output.writeBytes(bytes, 0, bytes.length);
    } catch (_:Dynamic) {
      alive = false;
    }
  }

  public function close():Void {
    alive = false;
    try socket.close() catch (_:Dynamic) {}
  }
}
