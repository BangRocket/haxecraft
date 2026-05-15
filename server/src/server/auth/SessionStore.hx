package server.auth;

class SessionStore {
  var tokens:Map<String, Int> = new Map();

  public function new() {}

  public function mint(accountId:Int):String {
    var tok = randomToken(24);
    tokens.set(tok, accountId);
    return tok;
  }

  public function accountIdFor(token:String):Null<Int> {
    return tokens.get(token);
  }

  public function revoke(token:String):Void {
    tokens.remove(token);
  }

  static function randomToken(nBytes:Int):String {
    var buf = new StringBuf();
    var hex = "0123456789abcdef";
    for (_ in 0...nBytes) {
      var b = Std.random(256);
      buf.add(hex.charAt((b >> 4) & 0xf));
      buf.add(hex.charAt(b & 0xf));
    }
    return buf.toString();
  }
}
