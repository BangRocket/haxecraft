package;

import utest.Test;
import utest.Assert;
import client.render.SpriteCatalog;
import shared.world.TileType;

class TestSpriteCatalog extends Test {
  function testEveryTileTypeHasASprite() {
    Assert.isTrue(SpriteCatalog.isComplete());
  }

  function testAllTilesListCoversEveryType() {
    Assert.equals(19, SpriteCatalog.ALL_TILES.length);
    for (tt in SpriteCatalog.ALL_TILES) {
      Assert.isTrue(SpriteCatalog.TILE_TABLE.exists((tt : Int)));
    }
  }

  function testTreeCellIsNonZero() {
    var tree = SpriteCatalog.TILE_TABLE.get((TileType.TREE : Int));
    Assert.equals("terrain", tree.sheet);
    Assert.equals(10, tree.col);
  }

  function testEveryItemTypeHasASprite() {
    Assert.isTrue(SpriteCatalog.itemsComplete());
  }

  function testAllItemsCoversCatalog() {
    Assert.equals(52, SpriteCatalog.ALL_ITEMS.length);
    for (it in SpriteCatalog.ALL_ITEMS) {
      Assert.isTrue(SpriteCatalog.ITEM_TABLE.exists((it : Int)));
    }
  }
}
