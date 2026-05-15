package server.zone;

import server.net.ClientConnection;

class Character {
  public var id:Int;
  public var name:String;
  public var conn:ClientConnection;  // may be null for offline/AI characters in future
  public var tileX:Int;
  public var tileY:Int;
  public var nextMoveTick:Int = 0;

  public function new(id:Int, name:String, conn:ClientConnection, tileX:Int, tileY:Int) {
    this.id = id;
    this.name = name;
    this.conn = conn;
    this.tileX = tileX;
    this.tileY = tileY;
  }
}
