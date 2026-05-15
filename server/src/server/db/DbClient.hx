package server.db;

import sys.db.Mysql;
import sys.db.Connection;

// Thin wrapper over Haxe stdlib sys.db.Mysql. Single connection per process for M0.
// Connection pooling deferred to M1.
//
// Placeholder convention: `?` in SQL is replaced by the next param value, properly escaped
// via cnx.addValue(). Caller must NOT use `?` inside string literals — for our internal
// queries this constraint holds.

class DbClient {
  var cnx:Connection;

  public function new(host:String, port:Int, db:String, user:String, password:String) {
    cnx = Mysql.connect({
      host: host,
      port: port,
      user: user,
      pass: password,
      database: db,
      socket: null
    });
  }

  /** Run a SELECT-style query. Returns rows as Array<Dynamic> with column-name fields. */
  public function query(sql:String, params:Array<Dynamic>):Array<Dynamic> {
    var rs = cnx.request(bindParams(sql, params));
    var rows = new Array<Dynamic>();
    while (rs.hasNext()) rows.push(rs.next());
    return rows;
  }

  /** Run a mutation (INSERT/UPDATE/DELETE). Returns affected-row count via ResultSet.length. */
  public function exec(sql:String, params:Array<Dynamic>):Int {
    var rs = cnx.request(bindParams(sql, params));
    return rs.length;
  }

  /** Returns the auto-increment id of the last INSERT on this connection. */
  public function lastInsertId():Int {
    return cnx.lastInsertId();
  }

  public function close():Void {
    cnx.close();
  }

  function bindParams(sql:String, params:Array<Dynamic>):String {
    if (params.length == 0) return sql;
    var sb = new StringBuf();
    var pi = 0;
    for (i in 0...sql.length) {
      var ch = sql.charAt(i);
      if (ch == "?") {
        if (pi >= params.length) throw "DbClient: too few params for placeholders in: " + sql;
        cnx.addValue(sb, params[pi++]);
      } else {
        sb.add(ch);
      }
    }
    if (pi != params.length) throw "DbClient: too many params (" + params.length + ") for placeholders in: " + sql;
    return sb.toString();
  }
}
