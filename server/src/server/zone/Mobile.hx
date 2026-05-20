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

  // Combat state (M3 SP1).
  public var str:Int = 50;
  public var dex:Int = 50;
  public var intel:Int = 50;     // `int` is reserved in Haxe
  public var hp:Int;
  public var maxHp:Int;
  public var nextSwingTick:Int = 0;
  /** 0 = not attacking; otherwise the target's serial. */
  public var attackTarget:Int = 0;

  public function new(serial:Int, name:String, conn:Null<ClientConnection>,
                      tileX:Int, tileY:Int) {
    this.serial = serial;
    this.name = name;
    this.conn = conn;
    this.tileX = tileX;
    this.tileY = tileY;
    // Placeholder maxHp formula; SP2 will recompute on stat changes.
    this.maxHp = 25 + Std.int(str / 2);
    this.hp = this.maxHp;
    this.inventory = new Inventory(this);
  }
}
