package server.zone;

import shared.item.ItemType;
import shared.item.ItemCategory;

/** Any addressable, non-mobile thing: dropped resource, placed furniture,
    inventory entry. Blocking is derived from `itemType.category()` so the
    same class covers ground-items and placed-furniture. */
class Item {
  public var serial:Int;
  public var itemType:ItemType;
  public var count:Int;
  public var parent:Null<Mobile>;
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public var slot:Int = 0;

  public function new(serial:Int, itemType:ItemType, count:Int) {
    this.serial = serial;
    this.itemType = itemType;
    this.count = count;
  }

  public inline function inWorld():Bool return parent == null;

  /** True if this item, when placed in the world, blocks movement. */
  public inline function blocksMovement():Bool {
    return itemType.category() == FURNITURE;
  }
}
