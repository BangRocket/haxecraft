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
import client.ui.InZoneScreen;
import shared.Constants;
import shared.proto.FrameCodec;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgZoneHandoff;
import shared.proto.MsgEnterZone;
import shared.proto.MsgEnterZoneAck;
import shared.proto.MsgType;

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
  var inZoneScreen:InZoneScreen;

  var pendingUsername:String = "";
  var pendingPassword:String = "";

  var ownEntityId:Int = 0;
  var ownTileX:Int = 0;
  var ownTileY:Int = 0;

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

    loginScreen = new LoginScreen(s2d);
    loginScreen.onSubmit = onLoginSubmit;
    hxd.Window.getInstance().addEventTarget(onEvent);
  }

  function onEvent(e:Event):Void {
    if (state == LOGGING_IN && loginScreen != null && loginScreen.parent != null) {
      loginScreen.handleKey(e);
    }
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
    ownTileX = ack.tileX;
    ownTileY = ack.tileY;
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
    inZoneScreen = new InZoneScreen(s2d);
    // World/entity renderers + input dispatcher hook into inZoneScreen in Tasks 21-23.
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
  }
}
