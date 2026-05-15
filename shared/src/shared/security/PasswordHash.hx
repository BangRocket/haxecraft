package shared.security;

// PBKDF2-SHA256, 100k iterations, 16-byte salt. Format: "pbkdf2$<iters>$<salt_hex>$<hash_hex>".
// M0 uses Std.random for salt (not crypto-secure); replace with libsodium binding before
// any non-localhost deployment. Acceptable for localhost-only M0 testing.

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.crypto.Hmac;

class PasswordHash {
  static inline var ITERATIONS = 100000;
  static inline var SALT_LEN = 16;
  static inline var KEY_LEN = 32;

  public static function hash(password:String):String {
    var salt = randomBytes(SALT_LEN);
    var key = pbkdf2Sha256(Bytes.ofString(password), salt, ITERATIONS, KEY_LEN);
    return "pbkdf2$" + ITERATIONS + "$" + salt.toHex() + "$" + key.toHex();
  }

  public static function verify(password:String, stored:String):Bool {
    var parts = stored.split("$");
    if (parts.length != 4 || parts[0] != "pbkdf2") return false;
    var iters = Std.parseInt(parts[1]);
    if (iters == null) return false;
    var salt = Bytes.ofHex(parts[2]);
    var expected = Bytes.ofHex(parts[3]);
    var actual = pbkdf2Sha256(Bytes.ofString(password), salt, iters, expected.length);
    return constantTimeEquals(expected, actual);
  }

  static function randomBytes(n:Int):Bytes {
    var b = Bytes.alloc(n);
    for (i in 0...n) b.set(i, Std.random(256));
    return b;
  }

  static function constantTimeEquals(a:Bytes, b:Bytes):Bool {
    if (a.length != b.length) return false;
    var diff = 0;
    for (i in 0...a.length) diff |= a.get(i) ^ b.get(i);
    return diff == 0;
  }

  static function pbkdf2Sha256(password:Bytes, salt:Bytes, iters:Int, keyLen:Int):Bytes {
    var hmac = new Hmac(SHA256);
    var blocks = Math.ceil(keyLen / 32);
    var out = Bytes.alloc(blocks * 32);
    for (i in 1...blocks + 1) {
      var saltBlock = Bytes.alloc(salt.length + 4);
      saltBlock.blit(0, salt, 0, salt.length);
      saltBlock.set(salt.length, (i >> 24) & 0xff);
      saltBlock.set(salt.length + 1, (i >> 16) & 0xff);
      saltBlock.set(salt.length + 2, (i >> 8) & 0xff);
      saltBlock.set(salt.length + 3, i & 0xff);
      var u = hmac.make(password, saltBlock);
      var t = u.sub(0, u.length);
      for (_ in 1...iters) {
        u = hmac.make(password, u);
        for (j in 0...t.length) t.set(j, t.get(j) ^ u.get(j));
      }
      out.blit((i - 1) * 32, t, 0, 32);
    }
    return out.sub(0, keyLen);
  }
}
