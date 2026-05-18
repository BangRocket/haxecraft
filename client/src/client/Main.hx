package client;

import hxd.App;
import hxd.Event;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import client.net.TcpConnection;
import client.net.ClientDispatcher;
import client.ui.LoginScreen;
import client.ui.ConnectingZoneScreen;
import client.ui.InventoryScreen;
import shared.Constants;
import shared.proto.FrameCodec;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgZoneHandoff;
import shared.proto.MsgEnterZone;
import shared.proto.MsgEnterZoneAck;
import shared.proto.MsgEntitySpawn;
import shared.proto.MsgEntityMove;
import shared.proto.MsgEntityDespawn;
import shared.proto.MsgGroundItemSpawn;
import shared.proto.MsgWorldObjectSpawn;
import shared.proto.MsgInventory;
import shared.proto.MsgGroundItemDespawn;
import shared.proto.MsgSelectActiveItem;
import shared.proto.MsgType;
import sys.io.File;
import shared.world.MapData;
import shared.world.TmxParser;
import client.render.ZoneRenderer;

enum ClientState {
  LOGGING_IN;
  AWAITING_ZONE_HANDOFF;
  CONNECTING_ZONE;
  IN_ZONE;
}

class Main extends App {
  var state:ClientState = LOGGING_IN;

  var gatewayConn:TcpConnection;
  var gatewayDispatcher:ClientDispatcher;

  var zoneConn:TcpConnection;
  var zoneDispatcher:ClientDispatcher;

  var loginScreen:LoginScreen;
  var connectingScreen:ConnectingZoneScreen;

  var pendingUsername:String = "";
  var pendingPassword:String = "";

  var ownEntityId:Int = 0;

  var map:MapData;
  var zoneRenderer:ZoneRenderer;
  var inputDispatcher:client.game.InputDispatcher;

  var inventoryScreen:InventoryScreen;
  var inventoryOpen:Bool = false;
  var invSlots:Array<{itemTypeId:Int, count:Int}> = [];
  var invActiveSlot:Int = 0;

  static function main() {
    new Main();
  }

  override function init() {
    gatewayDispatcher = new ClientDispatcher();
    gatewayDispatcher.on(MsgType.HELLO_ACK, onHelloAck);
    gatewayDispatcher.on(MsgType.LOGIN_ACK, onLoginAck);
    gatewayDispatcher.on(MsgType.ZONE_HANDOFF, onZoneHandoff);

    zoneDispatcher = new ClientDispatcher();
    zoneDispatcher.on(MsgType.ENTER_ZONE_ACK, onEnterZoneAck);
    zoneDispatcher.on(MsgType.ENTITY_SPAWN, onEntitySpawn);
    zoneDispatcher.on(MsgType.ENTITY_MOVE, onEntityMove);
    zoneDispatcher.on(MsgType.ENTITY_DESPAWN, onEntityDespawn);
    zoneDispatcher.on(MsgType.GROUND_ITEM_SPAWN, onGroundItemSpawn);
    zoneDispatcher.on(MsgType.WORLD_OBJECT_SPAWN, onWorldObjectSpawn);
    zoneDispatcher.on(MsgType.INVENTORY, onInventory);
    zoneDispatcher.on(MsgType.GROUND_ITEM_DESPAWN, onGroundItemDespawn);

    loginScreen = new LoginScreen(s2d);
    loginScreen.onSubmit = onLoginSubmit;
    hxd.Window.getInstance().addEventTarget(onEvent);
  }

  function onEvent(e:Event):Void {
    if (state == LOGGING_IN && loginScreen != null && loginScreen.parent != null) {
      loginScreen.handleKey(e);
      return;
    }
    if (state == IN_ZONE) {
      switch e.kind {
        case EKeyDown:
          if (e.keyCode == hxd.Key.I) {
            toggleInventory();
          } else if (e.keyCode >= hxd.Key.NUMBER_1 && e.keyCode <= hxd.Key.NUMBER_9) {
            selectActiveSlot(e.keyCode - hxd.Key.NUMBER_1);
          }
        default:
      }
    }
  }

  function onInventory(payload:Bytes):Void {
    var m = MsgInventory.deserialize(new BytesInput(payload));
    invSlots = m.slots;
    invActiveSlot = m.activeSlot;
    if (inventoryScreen != null) inventoryScreen.setSlots(invSlots, invActiveSlot);
  }

  function onGroundItemDespawn(payload:Bytes):Void {
    var m = MsgGroundItemDespawn.deserialize(new BytesInput(payload));
    if (zoneRenderer != null) zoneRenderer.removeGroundItem(m.worldItemId);
  }

  function toggleInventory():Void {
    inventoryOpen = !inventoryOpen;
    if (inventoryOpen) {
      inventoryScreen = new InventoryScreen(s2d);
      inventoryScreen.setSlots(invSlots, invActiveSlot);
    } else if (inventoryScreen != null) {
      inventoryScreen.remove();
      inventoryScreen = null;
    }
  }

  function selectActiveSlot(slot:Int):Void {
    if (zoneConn == null) return;
    var m = new MsgSelectActiveItem();
    m.slot = slot;
    var out = new BytesOutput(); m.serialize(out);
    zoneConn.sendFrame(MsgType.SELECT_ACTIVE_ITEM, out.getBytes());
  }

  function onLoginSubmit(username:String, password:String):Void {
    pendingUsername = username;
    pendingPassword = password;
    try {
      gatewayConn = new TcpConnection();
      gatewayConn.connect(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    } catch (e:Dynamic) {
      loginScreen.setStatus('connect failed: $e');
      return;
    }
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "client-m1";
    var p = new BytesOutput(); hello.serialize(p);
    gatewayConn.sendFrame(MsgType.HELLO, p.getBytes());
  }

  function onHelloAck(payload:Bytes):Void {
    var ack = MsgHelloAck.deserialize(new BytesInput(payload));
    if (!ack.ok) {
      loginScreen.setStatus('hello rejected: ${ack.reason}');
      gatewayConn.close();
      return;
    }
    var login = new MsgLogin();
    login.username = pendingUsername;
    login.password = pendingPassword;
    pendingPassword = "";
    var p = new BytesOutput(); login.serialize(p);
    gatewayConn.sendFrame(MsgType.LOGIN, p.getBytes());
  }

  function onLoginAck(payload:Bytes):Void {
    var ack = MsgLoginAck.deserialize(new BytesInput(payload));
    if (!ack.success) {
      loginScreen.setStatus('login failed: ${ack.errorMsg}');
      return;
    }
    state = AWAITING_ZONE_HANDOFF;
  }

  function onZoneHandoff(payload:Bytes):Void {
    var h = MsgZoneHandoff.deserialize(new BytesInput(payload));
    transitionToConnecting();
    try {
      zoneConn = new TcpConnection();
      zoneConn.connect(h.zoneHost, h.zonePort);
    } catch (e:Dynamic) {
      if (connectingScreen != null) { connectingScreen.remove(); connectingScreen = null; }
      loginScreen = new LoginScreen(s2d);
      loginScreen.onSubmit = onLoginSubmit;
      loginScreen.setStatus('zone connect failed: $e');
      state = LOGGING_IN;
      return;
    }
    var enter = new MsgEnterZone();
    enter.handoffToken = h.handoffToken;
    var p = new BytesOutput(); enter.serialize(p);
    zoneConn.sendFrame(MsgType.ENTER_ZONE, p.getBytes());
  }

  function onEnterZoneAck(payload:Bytes):Void {
    var ack = MsgEnterZoneAck.deserialize(new BytesInput(payload));
    if (!ack.success) {
      if (connectingScreen != null) { connectingScreen.remove(); connectingScreen = null; }
      loginScreen = new LoginScreen(s2d);
      loginScreen.onSubmit = onLoginSubmit;
      loginScreen.setStatus('enter-zone failed: ${ack.errorMsg}');
      state = LOGGING_IN;
      zoneConn.close();
      return;
    }
    ownEntityId = ack.entityId;
    transitionToInZone();
  }

  function transitionToConnecting():Void {
    state = CONNECTING_ZONE;
    if (loginScreen != null) { loginScreen.remove(); loginScreen = null; }
    connectingScreen = new ConnectingZoneScreen(s2d);
  }

  function transitionToInZone():Void {
    state = IN_ZONE;
    if (connectingScreen != null) { connectingScreen.remove(); connectingScreen = null; }
    if (map == null) {
      var xml = File.getContent("res/maps/starter.tmx");
      map = TmxParser.parse(xml);
    }
    zoneRenderer = new ZoneRenderer(s2d, map, ownEntityId);
    inputDispatcher = new client.game.InputDispatcher(zoneConn);
  }

  function onEntitySpawn(payload:Bytes):Void {
    var m = MsgEntitySpawn.deserialize(new BytesInput(payload));
    if (zoneRenderer != null) zoneRenderer.spawnEntity(m.entityId, m.name, m.tileX, m.tileY);
  }

  function onEntityMove(payload:Bytes):Void {
    var m = MsgEntityMove.deserialize(new BytesInput(payload));
    if (zoneRenderer != null) zoneRenderer.moveEntity(m.entityId, m.toX, m.toY, m.durationMs);
  }

  function onEntityDespawn(payload:Bytes):Void {
    var m = MsgEntityDespawn.deserialize(new BytesInput(payload));
    if (zoneRenderer != null) zoneRenderer.despawnEntity(m.entityId);
  }

  function onGroundItemSpawn(payload:Bytes):Void {
    var m = MsgGroundItemSpawn.deserialize(new BytesInput(payload));
    if (zoneRenderer != null)
      zoneRenderer.addGroundItem(m.worldItemId, m.itemTypeId, m.count, m.tileX, m.tileY);
  }

  function onWorldObjectSpawn(payload:Bytes):Void {
    var m = MsgWorldObjectSpawn.deserialize(new BytesInput(payload));
    if (zoneRenderer != null)
      zoneRenderer.addWorldObject(m.objectId, m.objectTypeId, m.tileX, m.tileY);
  }

  override function update(dt:Float) {
    if (gatewayConn != null && gatewayConn.state == CONNECTED) {
      var frames = gatewayConn.poll();
      for (f in frames) gatewayDispatcher.dispatch(f.msgType, f.payload);
    }
    if (zoneConn != null && zoneConn.state == CONNECTED) {
      var frames = zoneConn.poll();
      for (f in frames) zoneDispatcher.dispatch(f.msgType, f.payload);
    }
    if (state == IN_ZONE && zoneRenderer != null) {
      var own = zoneRenderer.ownPos();
      zoneRenderer.render(own.x, own.y);
      if (inputDispatcher != null) inputDispatcher.update();
    }
  }
}
