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

  function testTreeBaseIsGrassAndOverlayExists() {
    // TREE base renders the grass cell; the 16x16 canopy/trunk lives in
    // TREE_OVERLAY_{EDGE,INTERIOR}_CELLS and is drawn over the tile by
    // ZoneRenderer with per-quadrant edge/interior selection.
    var tree = SpriteCatalog.TILE_TABLE.get((TileType.TREE : Int));
    Assert.equals("terrain", tree.sheet);
    Assert.equals(0, tree.col);
    Assert.equals(0, tree.row);
    Assert.equals(4, SpriteCatalog.TREE_OVERLAY_EDGE_CELLS.length);
    Assert.equals(4, SpriteCatalog.TREE_OVERLAY_INTERIOR_CELLS.length);
    for (c in SpriteCatalog.TREE_OVERLAY_EDGE_CELLS) Assert.equals("terrain", c.sheet);
    for (c in SpriteCatalog.TREE_OVERLAY_INTERIOR_CELLS) Assert.equals("terrain", c.sheet);
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
