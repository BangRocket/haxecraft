package shared.world;

import haxe.io.Bytes;

class MapData {
  public var width(default, null):Int;
  public var height(default, null):Int;
  var tiles:Bytes;  // row-major, 1 byte per tile

  public function new(width:Int, height:Int, tiles:Bytes) {
    this.width = width;
    this.height = height;
    this.tiles = tiles;
  }

  public static function filled(width:Int, height:Int, fill:TileType):MapData {
    var b = Bytes.alloc(width * height);
    b.fill(0, b.length, (fill : Int) & 0xff);
    return new MapData(width, height, b);
  }

  /** Returns TileType.ROCK for out-of-bounds (treated as impassable). */
  public function tileAt(x:Int, y:Int):Int {
    if (x < 0 || y < 0 || x >= width || y >= height) return (TileType.ROCK : Int);
    return tiles.get(y * width + x);
  }

  public function setTile(x:Int, y:Int, t:TileType):Void {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    tiles.set(y * width + x, (t : Int) & 0xff);
  }

  public function isWalkable(x:Int, y:Int):Bool {
    var t:TileType = cast tileAt(x, y);
    return t.isWalkable();
  }

  public function rawBytes():Bytes return tiles;
}
