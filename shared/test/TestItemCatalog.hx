package;

import utest.Assert;
import utest.Test;
import shared.item.ItemType;
import shared.item.ItemCategory;

class TestItemCatalog extends Test {
  function testCatalogSize() {
    Assert.equals(52, ItemType.ALL.length);
  }

  function testCategoryCounts() {
    var r = 0, t = 0, f = 0;
    for (it in ItemType.ALL) {
      var c = it.category();
      if (c == ItemCategory.RESOURCE) r++;
      else if (c == ItemCategory.TOOL) t++;
      else if (c == ItemCategory.FURNITURE) f++;
    }
    Assert.equals(21, r);
    Assert.equals(25, t);
    Assert.equals(6, f);
  }

  function testIdsUnique() {
    var seen = new Map<Int, Bool>();
    for (it in ItemType.ALL) {
      var id:Int = it;
      Assert.isFalse(seen.exists(id), 'duplicate item id $id');
      seen.set(id, true);
    }
  }

  function testEveryItemHasNonEmptyName() {
    for (it in ItemType.ALL) {
      Assert.isTrue(it.name().length > 0);
    }
  }

  function testToolNamesCompose() {
    Assert.equals("Wood Shovel", ItemType.WOOD_SHOVEL.name());
    Assert.equals("Iron Pickaxe", ItemType.IRON_PICKAXE.name());
    Assert.equals("Gem Axe", ItemType.GEM_AXE.name());
  }

  function testStackability() {
    Assert.isTrue(ItemType.WOOD.stackable());       // resource
    Assert.isTrue(ItemType.IRON_ORE.stackable());   // resource
    Assert.isFalse(ItemType.GEM_AXE.stackable());   // tool
    Assert.isFalse(ItemType.CHEST.stackable());     // furniture
  }

  function testFurnitureCategory() {
    for (it in [ItemType.WORKBENCH, ItemType.FURNACE, ItemType.OVEN,
                ItemType.ANVIL, ItemType.CHEST, ItemType.LANTERN]) {
      Assert.equals(ItemCategory.FURNITURE, it.category());
    }
  }
}
