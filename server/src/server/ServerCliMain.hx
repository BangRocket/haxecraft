package server;

import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;

class ServerCliMain {
  public static function main() {
    var args = Sys.args();
    if (args.length < 1) { usage(); Sys.exit(1); }

    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var dal = new AccountDal(db);

    switch args[0] {
      case "create-account":
        if (args.length != 3) { usage(); Sys.exit(1); }
        var username = args[1];
        var password = args[2];
        if (dal.findByUsername(username) != null) {
          Sys.println('error: account "$username" already exists');
          Sys.exit(2);
        }
        var hash = PasswordHash.hash(password);
        var id = dal.create(username, hash);
        Sys.println('created account id=$id username=$username');
      default:
        usage();
        Sys.exit(1);
    }
    db.close();
  }

  static function usage() {
    Sys.println("usage: server-cli create-account <username> <password>");
  }
}
