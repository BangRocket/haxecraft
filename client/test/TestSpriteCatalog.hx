package;

import utest.Test;
import utest.Assert;
import client.render.SpriteCatalog;
import shared.world.TileType;

class TestSpriteCatalog extends Test {
  function testEveryTileTypeHasASprite() {
    Assert.isTrue(SpriteCatalog.isComplete());
  }

  function testAllTilesListCoversIds1To10() {
    Assert.equals(10, SpriteCatalog.ALL_TILES.length);
    for (tt in SpriteCatalog.ALL_TILES) {
      Assert.isTrue(SpriteCatalog.TILE_TABLE.exists((tt : Int)));
    }
  }

  function testTreeCellIsNonZero() {
    var tree = SpriteCatalog.TILE_TABLE.get((TileType.TREE : Int));
    Assert.equals("terrain", tree.sheet);
    Assert.equals(10, tree.col);
  }
}
