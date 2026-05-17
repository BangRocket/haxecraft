package;

import utest.Test;
import utest.Assert;
import shared.world.TileType;

class TestTileType extends Test {
  function testWalkableTypes() {
    Assert.isTrue((GRASS : TileType).isWalkable());
    Assert.isTrue((SAND : TileType).isWalkable());
    Assert.isTrue((DIRT : TileType).isWalkable());
    Assert.isTrue((FLOWER : TileType).isWalkable());
  }

  function testBlockedTypes() {
    Assert.isFalse((WATER : TileType).isWalkable());
    Assert.isFalse((STONE : TileType).isWalkable());
    Assert.isFalse((ROCK : TileType).isWalkable());
    Assert.isFalse((TREE : TileType).isWalkable());
    Assert.isFalse((LAVA : TileType).isWalkable());
    Assert.isFalse((CACTUS : TileType).isWalkable());
  }

  function testIdsAreContiguous() {
    Assert.equals(1, (GRASS : Int));
    Assert.equals(7, (DIRT : Int));
    Assert.equals(8, (FLOWER : Int));
    Assert.equals(9, (LAVA : Int));
    Assert.equals(10, (CACTUS : Int));
  }
}
