package server.db;

typedef Account = {
  id:Int,
  username:String,
  passwordHash:String
};

class AccountDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function findByUsername(username:String):Null<Account> {
    var rows = db.query(
      "SELECT id, username, password_hash FROM accounts WHERE username = ? LIMIT 1",
      [username]
    );
    if (rows.length == 0) return null;
    var r = rows[0];
    return { id: r.id, username: r.username, passwordHash: r.password_hash };
  }

  public function findById(id:Int):Null<Account> {
    var rows = db.query(
      "SELECT id, username, password_hash FROM accounts WHERE id = ? LIMIT 1",
      [id]
    );
    if (rows.length == 0) return null;
    var r = rows[0];
    return { id: r.id, username: r.username, passwordHash: r.password_hash };
  }

  public function create(username:String, passwordHash:String):Int {
    db.exec(
      "INSERT INTO accounts (username, password_hash) VALUES (?, ?)",
      [username, passwordHash]
    );
    return db.lastInsertId();
  }
}
