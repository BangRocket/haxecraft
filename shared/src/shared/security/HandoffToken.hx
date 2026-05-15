package shared.security;

import haxe.crypto.Hmac;
import haxe.io.Bytes;
import shared.Constants;

typedef HandoffPayload = {
  accountId:Int,
  characterId:Int
};

class HandoffToken {
  /** Mint a token with TTL seconds from now. */
  public static function mint(accountId:Int, characterId:Int, ttlSeconds:Int):String {
    var expiry = nowUnix() + ttlSeconds;
    var body = accountId + "|" + characterId + "|" + expiry;
    var sig = signHex(body);
    return body + "|" + sig;
  }

  /** Return null if the token is malformed, tampered, or expired. */
  public static function verify(token:String):Null<HandoffPayload> {
    if (token == null || token.length == 0) return null;
    var parts = token.split("|");
    if (parts.length != 4) return null;
    var accountId = Std.parseInt(parts[0]);
    var characterId = Std.parseInt(parts[1]);
    var expiry = Std.parseInt(parts[2]);
    var providedSig = parts[3];
    if (accountId == null || characterId == null || expiry == null) return null;

    var body = parts[0] + "|" + parts[1] + "|" + parts[2];
    var expectedSig = signHex(body);
    if (!constantTimeEq(expectedSig, providedSig)) return null;
    if (nowUnix() > expiry) return null;

    return { accountId: accountId, characterId: characterId };
  }

  static function signHex(body:String):String {
    var hmac = new Hmac(SHA256);
    var sig = hmac.make(Bytes.ofString(Constants.HANDOFF_SECRET), Bytes.ofString(body));
    return sig.toHex();
  }

  static function constantTimeEq(a:String, b:String):Bool {
    if (a.length != b.length) return false;
    var diff = 0;
    for (i in 0...a.length) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
    return diff == 0;
  }

  static function nowUnix():Int {
    return Std.int(Date.now().getTime() / 1000);
  }
}
