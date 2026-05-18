package;

import utest.Assert;
import utest.Test;
import server.zone.Inventory;
import shared.item.ItemType;

class TestInventory extends Test {
  function testResourcesStack() {
    var inv = new Inventory();
    inv.add(ItemType.WOOD, 3);
    inv.add(ItemType.WOOD, 4);
    Assert.equals(1, inv.slots.length);
    Assert.equals(7, inv.slots[0].count);
  }

  function testToolsDoNotStack() {
    var inv = new Inventory();
    inv.add(ItemType.GEM_AXE, 1);
    inv.add(ItemType.GEM_AXE, 1);
    Assert.equals(2, inv.slots.length);
  }

  function testHasAndRemove() {
    var inv = new Inventory();
    inv.add(ItemType.STONE, 10);
    Assert.isTrue(inv.has(ItemType.STONE, 10));
    Assert.isFalse(inv.has(ItemType.STONE, 11));
    Assert.isTrue(inv.removeCount(ItemType.STONE, 4));
    Assert.isTrue(inv.has(ItemType.STONE, 6));
    Assert.isFalse(inv.has(ItemType.STONE, 7));
  }

  function testRemoveTooMuchFails() {
    var inv = new Inventory();
    inv.add(ItemType.COAL, 2);
    Assert.isFalse(inv.removeCount(ItemType.COAL, 5));
    Assert.isTrue(inv.has(ItemType.COAL, 2));  // unchanged
  }

  function testRemoveEmptiesSlot() {
    var inv = new Inventory();
    inv.add(ItemType.WOOD, 3);
    inv.removeCount(ItemType.WOOD, 3);
    Assert.equals(0, inv.slots.length);
    Assert.isTrue(inv.isEmpty());
  }

  function testActiveItem() {
    var inv = new Inventory();
    Assert.isNull(inv.activeItem());
    inv.add(ItemType.WOOD, 1);
    inv.add(ItemType.STONE, 1);
    inv.activeSlot = 1;
    Assert.equals((ItemType.STONE : Int), (inv.activeItem().itemType : Int));
  }
}
