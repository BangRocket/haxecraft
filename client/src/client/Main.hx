package client;

import hxd.App;
import hxd.Event;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import client.net.TcpConnection;
import client.net.ClientDispatcher;
import client.ui.LoginScreen;
import client.ui.WelcomeScreen;
import shared.Constants;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgType;

class Main extends App {
  var conn:TcpConnection;
  var dispatcher:ClientDispatcher;
  var loginScreen:LoginScreen;
  var welcomeScreen:WelcomeScreen;
  var pendingUsername:String = "";
  var pendingPassword:String = "";

  static function main() {
    new Main();
  }

  override function init() {
    dispatcher = new ClientDispatcher();
    dispatcher.on(MsgType.HELLO_ACK, onHelloAck);
    dispatcher.on(MsgType.LOGIN_ACK, onLoginAck);

    loginScreen = new LoginScreen(s2d);
    loginScreen.onSubmit = onLoginSubmit;

    hxd.Window.getInstance().addEventTarget(onEvent);
  }

  function onEvent(e:Event):Void {
    if (loginScreen != null && loginScreen.parent != null) loginScreen.handleKey(e);
  }

  function onLoginSubmit(username:String, password:String):Void {
    pendingUsername = username;
    pendingPassword = password;
    try {
      conn = new TcpConnection();
      conn.connect(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    } catch (e:Dynamic) {
      loginScreen.setStatus('connect failed: $e');
      return;
    }
    // Send Hello immediately
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "client-m0";
    var p = new BytesOutput(); hello.serialize(p);
    conn.sendFrame(MsgType.HELLO, p.getBytes());
  }

  function onHelloAck(payload:Bytes):Void {
    var ack = MsgHelloAck.deserialize(new BytesInput(payload));
    if (!ack.ok) {
      loginScreen.setStatus('hello rejected: ${ack.reason}');
      conn.close();
      return;
    }
    // Now send Login
    var login = new MsgLogin();
    login.username = pendingUsername;
    login.password = pendingPassword;
    pendingPassword = "";  // don't keep it around
    var p = new BytesOutput(); login.serialize(p);
    conn.sendFrame(MsgType.LOGIN, p.getBytes());
  }

  function onLoginAck(payload:Bytes):Void {
    var ack = MsgLoginAck.deserialize(new BytesInput(payload));
    if (!ack.success) {
      loginScreen.setStatus('login failed: ${ack.errorMsg}');
      return;
    }
    loginScreen.remove();
    loginScreen = null;
    welcomeScreen = new WelcomeScreen(s2d, pendingUsername);
  }

  override function update(dt:Float) {
    if (conn != null && conn.state == CONNECTED) {
      var frames = conn.poll();
      for (f in frames) dispatcher.dispatch(f.msgType, f.payload);
    }
  }
}
