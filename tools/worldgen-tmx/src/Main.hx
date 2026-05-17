import shared.world.TileType;
import sys.io.File;

class Main {
  static inline var FREQ:Float = 0.012;
  static inline var SEED:Int = 0xC0FFEE;

  public static function main() {
    var args = Sys.args();
    var width = args.length > 0 ? Std.parseInt(args[0]) : 1024;
    var height = args.length > 1 ? Std.parseInt(args[1]) : 1024;
    var outPath = args.length > 2 ? args[2] : "res/maps/starter.tmx";
    if (width == null || height == null || width <= 0 || height <= 0) {
      Sys.println("usage: worldgen-tmx [width=1024] [height=1024] [out=res/maps/starter.tmx]");
      Sys.exit(1);
    }

    var tiles = generate(width, height);
    var xml = writeTmx(width, height, tiles);
    File.saveContent(outPath, xml);
    Sys.println('wrote $outPath ($width x $height)');
  }

  static function generate(width:Int, height:Int):Array<Int> {
    var tiles = [for (_ in 0...width * height) (TileType.GRASS : Int)];
    for (y in 0...height) {
      for (x in 0...width) {
        var n = noise(x, y);
        var t:TileType =
          if (n < -0.30) TileType.WATER
          else if (n < -0.10) TileType.SAND
          else if (n <  0.30) TileType.GRASS
          else if (n <  0.55) TileType.STONE
          else                TileType.ROCK;
        tiles[y * width + x] = (t : Int);
      }
    }

    var rng = SEED;
    for (y in 0...height) {
      for (x in 0...width) {
        rng = mix32(rng + x * 374761393 + y * 668265263);
        var idx = y * width + x;
        var t = tiles[idx];
        var roll = rng & 0xff;
        if (t == (TileType.GRASS : Int)) {
          if (roll < 6)        tiles[idx] = (TileType.TREE : Int);
          else if (roll < 30)  tiles[idx] = (TileType.DIRT : Int);
          else if (roll < 38)  tiles[idx] = (TileType.FLOWER : Int);
        } else if (t == (TileType.SAND : Int)) {
          if (roll < 5)        tiles[idx] = (TileType.CACTUS : Int);
        } else if (t == (TileType.ROCK : Int)) {
          if (roll < 8)        tiles[idx] = (TileType.LAVA : Int);
        }
      }
    }
    return tiles;
  }

  static function noise(x:Int, y:Int):Float {
    var fx = x * FREQ;
    var fy = y * FREQ;
    var x0 = Math.floor(fx);
    var y0 = Math.floor(fy);
    var dx = fx - x0;
    var dy = fy - y0;
    var v00 = hashUnit(x0, y0);
    var v10 = hashUnit(x0 + 1, y0);
    var v01 = hashUnit(x0, y0 + 1);
    var v11 = hashUnit(x0 + 1, y0 + 1);
    var sx = smooth(dx);
    var sy = smooth(dy);
    var a = v00 + (v10 - v00) * sx;
    var b = v01 + (v11 - v01) * sx;
    return a + (b - a) * sy;
  }

  static inline function smooth(t:Float):Float return t * t * (3 - 2 * t);

  static function hashUnit(x:Int, y:Int):Float {
    var h = mix32(SEED ^ (x * 374761393) ^ (y * 668265263));
    return ((h & 0xffff) / 32768.0) - 1.0;
  }

  static function mix32(x:Int):Int {
    x = (x ^ (x >>> 16)) * 0x7feb352d;
    x = (x ^ (x >>> 15)) * 0x846ca68b;
    return x ^ (x >>> 16);
  }

  static function writeTmx(width:Int, height:Int, tiles:Array<Int>):String {
    var sb = new StringBuf();
    sb.add('<?xml version="1.0" encoding="UTF-8"?>\n');
    sb.add('<map version="1.10" orientation="orthogonal" renderorder="right-down" ');
    sb.add('width="$width" height="$height" tilewidth="8" tileheight="8" infinite="0">\n');
    sb.add('  <tileset firstgid="1" name="terrain" tilewidth="8" tileheight="8" tilecount="10"/>\n');
    sb.add('  <layer id="1" name="terrain" width="$width" height="$height">\n');
    sb.add('    <data encoding="csv">\n');
    for (y in 0...height) {
      var row = new StringBuf();
      for (x in 0...width) {
        if (x > 0) row.add(",");
        row.add(tiles[y * width + x]);
      }
      if (y < height - 1) row.add(",");
      sb.add(row.toString());
      sb.add("\n");
    }
    sb.add('</data>\n');
    sb.add('  </layer>\n');
    sb.add('</map>\n');
    return sb.toString();
  }
}
