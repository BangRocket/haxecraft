package;

import utest.Assert;
import utest.Test;
import shared.item.ItemStack;
import shared.item.ItemType;

class TestItemStack extends Test {
  function testConstruct() {
    var s = new ItemStack(ItemType.WOOD, 5);
    Assert.equals((ItemType.WOOD : Int), (s.itemType : Int));
    Assert.equals(5, s.count);
  }

  function testDefaultCountIsOne() {
    Assert.equals(1, new ItemStack(ItemType.GEM_AXE).count);
  }

  function testCloneIsIndependent() {
    var a = new ItemStack(ItemType.STONE, 3);
    var b = a.clone();
    b.count = 9;
    Assert.equals(3, a.count);
    Assert.equals((ItemType.STONE : Int), (b.itemType : Int));
  }
}
