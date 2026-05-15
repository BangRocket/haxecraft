package;

import utest.Assert;
import utest.Test;
import shared.world.MapData;
import shared.world.TileType;

class TestMapData extends Test {
  function testEmptyMapAllGrass() {
    var m = MapData.filled(4, 4, TileType.GRASS);
    Assert.equals(4, m.width);
    Assert.equals(4, m.height);
    Assert.equals((TileType.GRASS : Int), m.tileAt(2, 2));
  }

  function testTileAtRespectsRowMajor() {
    var m = MapData.filled(3, 2, TileType.GRASS);
    m.setTile(0, 0, TileType.WATER);
    m.setTile(2, 1, TileType.ROCK);
    Assert.equals((TileType.WATER : Int), m.tileAt(0, 0));
    Assert.equals((TileType.GRASS : Int), m.tileAt(1, 0));
    Assert.equals((TileType.ROCK : Int), m.tileAt(2, 1));
  }

  function testOutOfBoundsReadsRock() {
    var m = MapData.filled(3, 3, TileType.GRASS);
    Assert.equals((TileType.ROCK : Int), m.tileAt(-1, 0));
    Assert.equals((TileType.ROCK : Int), m.tileAt(0, 99));
  }

  function testIsWalkableUsesTileType() {
    var m = MapData.filled(2, 2, TileType.GRASS);
    m.setTile(1, 1, TileType.WATER);
    Assert.isTrue(m.isWalkable(0, 0));
    Assert.isFalse(m.isWalkable(1, 1));
    Assert.isFalse(m.isWalkable(-1, -1));
  }
}
