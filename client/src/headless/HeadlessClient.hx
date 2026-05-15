package headless;

import sys.net.Socket;
import sys.net.Host;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import shared.Constants;
import shared.proto.FrameCodec;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgZoneHandoff;
import shared.proto.MsgEnterZone;
import shared.proto.MsgEnterZoneAck;
import shared.proto.MsgMoveIntent;
import shared.proto.MsgEntityMove;
import shared.proto.MsgEntitySpawn;
import shared.proto.MsgType;
import shared.world.Direction;

/**
  Programmable client driving the M1 protocol synchronously. Not for high
  throughput - for clarity in tests. Each high-level call blocks until the
  corresponding server response is read.
**/
class HeadlessClient {
  public var gateway(default, null):Socket;
  public var zone(default, null):Socket;
  public var entityId(default, null):Int = 0;
  public var tileX(default, null):Int = 0;
  public var tileY(default, null):Int = 0;
  public var sessionToken(default, null):String = "";
  public var handoffToken(default, null):String = "";

  public function new() {}

  public function connectGateway(host:String = "127.0.0.1", port:Int = 7777):Void {
    gateway = new Socket();
    gateway.connect(new Host(host), port);
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "headless-test";
    writeFrame(gateway, MsgType.HELLO, hello);
    var f = FrameCodec.readFrame(gateway.input);
    if ((f.msgType : Int) != (MsgType.HELLO_ACK : Int)) throw 'expected HELLO_ACK got ${f.msgType}';
    var ack = MsgHelloAck.deserialize(new BytesInput(f.payload));
    if (!ack.ok) throw 'HelloAck rejected: ${ack.reason}';
  }

  public function login(username:String, password:String):Bool {
    var login = new MsgLogin();
    login.username = username;
    login.password = password;
    writeFrame(gateway, MsgType.LOGIN, login);
    var ackFrame = FrameCodec.readFrame(gateway.input);
    if ((ackFrame.msgType : Int) != (MsgType.LOGIN_ACK : Int)) throw 'expected LOGIN_ACK got ${ackFrame.msgType}';
    var ack = MsgLoginAck.deserialize(new BytesInput(ackFrame.payload));
    if (!ack.success) return false;
    sessionToken = ack.sessionToken;
    var handoffFrame = FrameCodec.readFrame(gateway.input);
    if ((handoffFrame.msgType : Int) != (MsgType.ZONE_HANDOFF : Int)) throw 'expected ZONE_HANDOFF got ${handoffFrame.msgType}';
    var h = MsgZoneHandoff.deserialize(new BytesInput(handoffFrame.payload));
    handoffToken = h.handoffToken;
    return true;
  }

  public function enterZone(host:String = "127.0.0.1", port:Int = 7778):Void {
    zone = new Socket();
    zone.connect(new Host(host), port);
    var ez = new MsgEnterZone();
    ez.handoffToken = handoffToken;
    writeFrame(zone, MsgType.ENTER_ZONE, ez);

    var ackFrame = FrameCodec.readFrame(zone.input);
    if ((ackFrame.msgType : Int) != (MsgType.ENTER_ZONE_ACK : Int)) throw 'expected ENTER_ZONE_ACK got ${ackFrame.msgType}';
    var ack = MsgEnterZoneAck.deserialize(new BytesInput(ackFrame.payload));
    if (!ack.success) throw 'EnterZone rejected: ${ack.errorMsg}';
    entityId = ack.entityId;
    tileX = ack.tileX;
    tileY = ack.tileY;

    // Server then emits our own EntitySpawn frame; consume it.
    var spawnFrame = FrameCodec.readFrame(zone.input);
    if ((spawnFrame.msgType : Int) != (MsgType.ENTITY_SPAWN : Int)) {
      throw 'expected ENTITY_SPAWN got ${spawnFrame.msgType}';
    }
  }

  /** Issue MoveIntent + consume EntityMove echo. Returns true on accept. **/
  public function move(dir:Direction, ackTimeoutS:Float = 1.0):Bool {
    var m = new MsgMoveIntent();
    m.dir = (dir : Int);
    writeFrame(zone, MsgType.MOVE_INTENT, m);

    var deadline = haxe.Timer.stamp() + ackTimeoutS;
    while (haxe.Timer.stamp() < deadline) {
      zone.setTimeout(0.05);
      try {
        var frame = FrameCodec.readFrame(zone.input);
        if ((frame.msgType : Int) == (MsgType.ENTITY_MOVE : Int)) {
          var em = MsgEntityMove.deserialize(new BytesInput(frame.payload));
          if (em.entityId == entityId) {
            tileX = em.toX;
            tileY = em.toY;
            return true;
          }
        }
      } catch (_:haxe.io.Eof) {
        return false;
      } catch (_:Dynamic) {
        // read timeout - keep polling until deadline
      }
    }
    return false;
  }

  public function close():Void {
    if (zone != null) try zone.close() catch (_:Dynamic) {}
    if (gateway != null) try gateway.close() catch (_:Dynamic) {}
  }

  static function writeFrame(s:Socket, msgType:Int, msg:Dynamic):Void {
    var p = new BytesOutput();
    msg.serialize(p);
    var frame = new BytesOutput();
    FrameCodec.writeFrame(frame, msgType, p.getBytes());
    var b = frame.getBytes();
    s.output.writeBytes(b, 0, b.length);
  }
}
