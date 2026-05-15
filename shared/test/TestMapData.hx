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

  function testFindWalkableNearReturnsSelfWhenWalkable() {
    var m = MapData.filled(5, 5, TileType.GRASS);
    var pos = m.findWalkableNear(2, 2);
    Assert.equals(2, pos.x);
    Assert.equals(2, pos.y);
  }

  function testFindWalkableNearSpiralsOut() {
    // Center 3x3 is water, surrounded by grass.
    var m = MapData.filled(7, 7, TileType.GRASS);
    for (dy in -1...2) for (dx in -1...2) m.setTile(3 + dx, 3 + dy, TileType.WATER);
    var pos = m.findWalkableNear(3, 3);
    // The found tile must be walkable and within 2 of center.
    Assert.isTrue(m.isWalkable(pos.x, pos.y));
    Assert.isTrue(Math.abs(pos.x - 3) <= 2);
    Assert.isTrue(Math.abs(pos.y - 3) <= 2);
  }
}
