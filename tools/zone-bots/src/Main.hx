import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;
import sys.thread.Thread;

/**
 * Headless-bot runner — puts many players into one zone for load/soak
 * testing and as the M2 CI multi-player smoke test.
 *
 *   zone-bots [--count N] [--duration S]
 *
 * Exits non-zero if any bot raised an error.
 */
class Main {
  static inline var PW = "bot-pass";

  public static function main() {
    var args = Sys.args();
    var count = argInt(args, "--count", 8);
    var duration = argFloat(args, "--duration", 15.0);
    Sys.println('[zone-bots] launching $count bots for ${duration}s');

    ensureAccounts(count);

    var bots = [for (i in 0...count) new Bot(Std.string(i), 0x9E37 + i * 7919)];
    for (i in 0...count) {
      var bot = bots[i];
      var uname = 'bot_$i';
      Thread.create(() -> bot.run(uname, PW, duration));
    }

    // Give the bot threads the run plus a margin to finish, then report.
    Sys.sleep(duration + 4.0);

    var totalActions = 0;
    var errored = 0;
    for (b in bots) {
      totalActions += b.actions;
      if (b.error != null) {
        errored++;
        Sys.println('[zone-bots] bot ${b.name} ERROR: ${b.error}');
      }
    }
    Sys.println('[zone-bots] done: $count bots, $totalActions actions, $errored errored');
    Sys.exit(errored > 0 ? 1 : 0);
  }

  /** Create any missing bot_0..bot_{N-1} accounts. */
  static function ensureAccounts(count:Int):Void {
    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var accounts = new AccountDal(db);
    var created = 0;
    for (i in 0...count) {
      var uname = 'bot_$i';
      if (accounts.findByUsername(uname) == null) {
        accounts.create(uname, PasswordHash.hash(PW));
        created++;
      }
    }
    db.close();
    Sys.println('[zone-bots] accounts ready ($created created)');
  }

  static function argInt(args:Array<String>, flag:String, def:Int):Int {
    var i = args.indexOf(flag);
    if (i >= 0 && i + 1 < args.length) {
      var v = Std.parseInt(args[i + 1]);
      if (v != null) return v;
    }
    return def;
  }

  static function argFloat(args:Array<String>, flag:String, def:Float):Float {
    var i = args.indexOf(flag);
    if (i >= 0 && i + 1 < args.length) {
      var v = Std.parseFloat(args[i + 1]);
      if (!Math.isNaN(v)) return v;
    }
    return def;
  }
}
