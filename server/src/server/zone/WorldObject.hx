package server.zone;

import shared.item.ItemType;

/** A placed furniture object. Blocking — it occupies its tile.
    Static in SP2; interaction arrives in SP4. */
class WorldObject {
  public var id:Int;
  public var objectType:ItemType;
  public var tileX:Int;
  public var tileY:Int;

  public function new(id:Int, objectType:ItemType, tileX:Int, tileY:Int) {
    this.id = id;
    this.objectType = objectType;
    this.tileX = tileX;
    this.tileY = tileY;
  }
}
