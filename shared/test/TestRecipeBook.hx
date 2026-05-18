package;

import utest.Assert;
import utest.Test;
import shared.item.RecipeBook;
import shared.item.CraftStation;
import shared.item.ItemType;

class TestRecipeBook extends Test {
  function testTotalRecipeCount() {
    Assert.equals(35, RecipeBook.ALL.length);
  }

  function testStationCounts() {
    Assert.equals(16, RecipeBook.forStation(CraftStation.WORKBENCH).length);
    Assert.equals(15, RecipeBook.forStation(CraftStation.ANVIL).length);
    Assert.equals(3, RecipeBook.forStation(CraftStation.FURNACE).length);
    Assert.equals(1, RecipeBook.forStation(CraftStation.OVEN).length);
  }

  function testRecipeIdsUnique() {
    var seen = new Map<Int, Bool>();
    for (r in RecipeBook.ALL) {
      Assert.isFalse(seen.exists(r.id));
      seen.set(r.id, true);
    }
  }

  function testEveryRecipeHasInputsAndOutput() {
    for (r in RecipeBook.ALL) {
      Assert.isTrue(r.inputs.length > 0);
      Assert.isTrue(r.outputCount > 0);
    }
  }

  function testByIdLookup() {
    Assert.notNull(RecipeBook.byId(1));
    Assert.isNull(RecipeBook.byId(9999));
  }

  function testFurnaceSmeltsIngot() {
    var smelt = RecipeBook.forStation(CraftStation.FURNACE);
    var found = false;
    for (r in smelt) if ((r.output : Int) == (ItemType.IRON_INGOT : Int)) found = true;
    Assert.isTrue(found);
  }
}
