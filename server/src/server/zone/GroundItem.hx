package server.zone;

import shared.item.ItemType;

/** An item lying in the world. Non-blocking — players walk over it.
    Static in SP2; pickup arrives in SP3. */
class GroundItem {
  public var id:Int;
  public var itemType:ItemType;
  public var count:Int;
  public var tileX:Int;
  public var tileY:Int;

  public function new(id:Int, itemType:ItemType, count:Int, tileX:Int, tileY:Int) {
    this.id = id;
    this.itemType = itemType;
    this.count = count;
    this.tileX = tileX;
    this.tileY = tileY;
  }
}
