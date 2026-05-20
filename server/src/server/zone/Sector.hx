package server.zone;

/** A single cell of the `SectorGrid`. Holds the world-placed entities
    whose tile falls inside the cell's 8x8 footprint. Mobiles and items
    are kept in separate arrays so kind-specific lookups don't scan the
    other kind. */
class Sector {
  public var sx:Int;
  public var sy:Int;
  public var mobiles:Array<Mobile> = [];
  public var items:Array<Item> = [];

  public function new(sx:Int, sy:Int) {
    this.sx = sx;
    this.sy = sy;
  }
}
