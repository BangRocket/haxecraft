package;

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
import shared.proto.MsgChat;
import shared.proto.MsgSelectActiveItem;
import shared.proto.MsgUseItemOnTile;
import shared.proto.MsgType;
import shared.world.Direction;
import shared.item.ItemType;
import shared.item.ItemCategory;

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
  // SP2: counts from the zone-entry static-world burst.
  public var worldObjectCount(default, null):Int = 0;
  public var groundItemCount(default, null):Int = 0;

  // Non-burst zone frames read during enterZone's burst-drain — buffered here
  // so they aren't lost (e.g. an interest EntitySpawn arriving mid-burst).
  var pendingZoneFrames:Array<{msgType:Int, payload:Bytes}> = [];

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

    // SP2: drain the static-world spawn burst. After the wire collapse,
    // furniture + ground items both arrive as ENTITY_SPAWN with item-range
    // serials (top bit set) — categorize by the embedded itemTypeId.
    worldObjectCount = 0;
    groundItemCount = 0;
    var deadline = haxe.Timer.stamp() + 1.0;
    while (haxe.Timer.stamp() < deadline) {
      zone.setTimeout(0.05);
      try {
        var f = FrameCodec.readFrame(zone.input);
        var mt:Int = f.msgType;
        if (mt == (MsgType.ENTITY_SPAWN : Int)) {
          var sp = MsgEntitySpawn.deserialize(new BytesInput(f.payload));
          if ((sp.entityId & 0x40000000) != 0 && sp.parentSerial == 0) {
            var t:ItemType = sp.itemTypeId;
            if (t.category() == ItemCategory.FURNITURE) worldObjectCount++;
            else groundItemCount++;
          } else {
            // Mobile spawn (other players in interest range) — buffer for later.
            pendingZoneFrames.push({ msgType: mt, payload: f.payload });
          }
        } else {
          pendingZoneFrames.push({ msgType: mt, payload: f.payload });
        }
      } catch (_:haxe.io.Eof) {
        break;
      } catch (_:Dynamic) {
        break;  // read timeout — the burst is drained
      }
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

  /** Read whatever zone frames arrive within `durationS`, return them all.
      Used by tests to observe spawns/moves of other entities. **/
  public function drainFrames(durationS:Float):Array<{msgType:Int, payload:Bytes}> {
    var out:Array<{msgType:Int, payload:Bytes}> = pendingZoneFrames;
    pendingZoneFrames = [];
    var deadline = haxe.Timer.stamp() + durationS;
    while (haxe.Timer.stamp() < deadline) {
      zone.setTimeout(0.05);
      try {
        var f = FrameCodec.readFrame(zone.input);
        out.push({ msgType: (f.msgType : Int), payload: f.payload });
      } catch (_:haxe.io.Eof) {
        break;
      } catch (_:Dynamic) {
        // read timeout — keep polling until the deadline
      }
    }
    return out;
  }

  /** Send a chat message: GLOBAL goes via the gateway socket, others via zone. **/
  public function sendChat(channel:Int, text:String):Void {
    var m = new MsgChat();
    m.channel = channel;
    m.senderName = "";
    m.text = text;
    var sock = (channel == (shared.proto.ChatChannel.GLOBAL : Int)) ? gateway : zone;
    writeFrame(sock, MsgType.CHAT, m);
  }

  /** Select the active inventory slot (SP3). **/
  public function selectActiveSlot(slot:Int):Void {
    var m = new MsgSelectActiveItem();
    m.slot = slot;
    writeFrame(zone, MsgType.SELECT_ACTIVE_ITEM, m);
  }

  /** Use the active item on a tile (SP4 gathering). **/
  public function useItemOnTile(tileX:Int, tileY:Int):Void {
    var m = new MsgUseItemOnTile();
    m.tileX = tileX;
    m.tileY = tileY;
    writeFrame(zone, MsgType.USE_ITEM_ON_TILE, m);
  }

  /** Like drainFrames, but reads the gateway socket (for global chat). **/
  public function drainGatewayFrames(durationS:Float):Array<{msgType:Int, payload:Bytes}> {
    var out:Array<{msgType:Int, payload:Bytes}> = [];
    var deadline = haxe.Timer.stamp() + durationS;
    while (haxe.Timer.stamp() < deadline) {
      gateway.setTimeout(0.05);
      try {
        var f = FrameCodec.readFrame(gateway.input);
        out.push({ msgType: (f.msgType : Int), payload: f.payload });
      } catch (_:haxe.io.Eof) {
        break;
      } catch (_:Dynamic) {
        // read timeout — keep polling until the deadline
      }
    }
    return out;
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
