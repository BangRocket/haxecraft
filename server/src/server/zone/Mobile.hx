package server.zone;

import server.net.ClientConnection;

/** A live actor in a zone: player (conn != null) or future NPC (conn == null).
    Replaces the previous `Character` class. */
class Mobile {
  public var serial:Int;
  public var name:String;
  public var conn:Null<ClientConnection>;
  public var tileX:Int;
  public var tileY:Int;
  public var nextMoveTick:Int = 0;
  /** Latest queued Direction (0..3) from a MoveIntent; -1 = nothing held. */
  public var pendingDir:Int = -1;
  public var inventory:Inventory;

  public function new(serial:Int, name:String, conn:Null<ClientConnection>,
                      tileX:Int, tileY:Int) {
    this.serial = serial;
    this.name = name;
    this.conn = conn;
    this.tileX = tileX;
    this.tileY = tileY;
    this.inventory = new Inventory(this);
  }
}
