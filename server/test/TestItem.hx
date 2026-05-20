package;

import utest.Assert;
import utest.Test;
import server.zone.Item;
import server.zone.Mobile;
import shared.item.ItemType;

class TestItem extends Test {
  function testStartsInWorld() {
    var it = new Item(0x40000000, ItemType.WOOD, 3);
    Assert.isTrue(it.inWorld());
    Assert.isFalse(it.blocksMovement());   // wood doesn't block
  }

  function testFurnitureBlocks() {
    var it = new Item(0x40000001, ItemType.WORKBENCH, 1);
    Assert.isTrue(it.blocksMovement());
  }

  function testParentToggle() {
    var it = new Item(0x40000002, ItemType.STONE, 5);
    var m = new Mobile(1, "x", null, 0, 0);
    it.parent = m;
    Assert.isFalse(it.inWorld());
    it.parent = null;
    Assert.isTrue(it.inWorld());
  }
}
