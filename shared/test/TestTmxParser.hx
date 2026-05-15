package;

import utest.Assert;
import utest.Test;
import shared.world.TmxParser;
import shared.world.TileType;

class TestTmxParser extends Test {
  static var TINY_TMX = '<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="3" height="2" tilewidth="8" tileheight="8" infinite="0">
  <tileset firstgid="1" name="terrain" tilewidth="8" tileheight="8" tilecount="6"/>
  <layer id="1" name="terrain" width="3" height="2">
    <data encoding="csv">
1,2,3,
4,5,6
</data>
  </layer>
</map>';

  function testParsesDimensions() {
    var m = TmxParser.parse(TINY_TMX);
    Assert.equals(3, m.width);
    Assert.equals(2, m.height);
  }

  function testParsesTilesRowMajor() {
    var m = TmxParser.parse(TINY_TMX);
    Assert.equals((TileType.GRASS : Int), m.tileAt(0, 0));
    Assert.equals((TileType.SAND  : Int), m.tileAt(1, 0));
    Assert.equals((TileType.WATER : Int), m.tileAt(2, 0));
    Assert.equals((TileType.STONE : Int), m.tileAt(0, 1));
    Assert.equals((TileType.ROCK  : Int), m.tileAt(1, 1));
    Assert.equals((TileType.TREE  : Int), m.tileAt(2, 1));
  }

  function testRejectsMismatchedRowCount() {
    var bad = StringTools.replace(TINY_TMX, '1,2,3,\n4,5,6', '1,2,3');
    Assert.raises(() -> TmxParser.parse(bad));
  }
}
