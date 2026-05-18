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

  function testInteractiveWalkableTypes() {
    Assert.isTrue((FARMLAND : TileType).isWalkable());
    Assert.isTrue((WHEAT : TileType).isWalkable());
    Assert.isTrue((HOLE : TileType).isWalkable());
    Assert.isTrue((TREE_SAPLING : TileType).isWalkable());
    Assert.isTrue((CACTUS_SAPLING : TileType).isWalkable());
  }

  function testInteractiveBlockedTypes() {
    Assert.isFalse((IRON_ORE : TileType).isWalkable());
    Assert.isFalse((GOLD_ORE : TileType).isWalkable());
    Assert.isFalse((GEM_ORE : TileType).isWalkable());
    Assert.isFalse((HARD_ROCK : TileType).isWalkable());
  }

  function testInteractiveIds() {
    Assert.equals(11, (IRON_ORE : Int));
    Assert.equals(19, (HOLE : Int));
  }
}
