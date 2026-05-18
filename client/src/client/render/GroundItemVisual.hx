package client.render;

import shared.item.ItemType;

/** A static ground item, client-side. SP2 renders these; they do not move
    and are not yet pickable (SP3). */
class GroundItemVisual {
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
