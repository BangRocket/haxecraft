package shared.proto;

enum abstract MsgType(Int) to Int from Int {
  var HELLO = 1;
  var HELLO_ACK = 2;
  var LOGIN = 3;
  var LOGIN_ACK = 4;
  var ERROR = 5;
}
