package;

import utest.Assert;
import utest.Test;
import server.zone.Inventory;
import server.zone.Mobile;
import server.zone.Item;
import server.zone.Serials;
import server.zone.SerialCounter;
import shared.item.ItemType;

/** In-memory counter double so the test allocates fresh serials. */
private class MemCounter implements SerialCounter {
  public var mobile:Int = 1;
  public var item:Int = 0x40000000;
  public function new() {}
  public function loadMobileNext():Int return mobile;
  public function loadItemNext():Int return item;
  public function storeMobileNext(v:Int):Void { mobile = v; }
  public function storeItemNext(v:Int):Void { item = v; }
}

class TestInventory extends Test {
  var serials:Serials;
  var owner:Mobile;

  function setup() {
    serials = new Serials(new MemCounter());
    owner = new Mobile(serials.nextMobile(), "owner", null, 0, 0);
  }

  function fresh(t:ItemType, c:Int):Item {
    return new Item(serials.nextItem(), t, c);
  }

  function testResourcesStack() {
    var inv = owner.inventory;
    inv.addFresh(fresh(ItemType.WOOD, 3));
    inv.addFresh(fresh(ItemType.WOOD, 4));
    Assert.equals(1, inv.slots.length);
    Assert.equals(7, inv.slots[0].count);
  }

  function testToolsDoNotStack() {
    var inv = owner.inventory;
    inv.addFresh(fresh(ItemType.GEM_AXE, 1));
    inv.addFresh(fresh(ItemType.GEM_AXE, 1));
    Assert.equals(2, inv.slots.length);
  }

  function testHasAndRemove() {
    var inv = owner.inventory;
    inv.addFresh(fresh(ItemType.STONE, 10));
    Assert.isTrue(inv.has(ItemType.STONE, 10));
    Assert.isFalse(inv.has(ItemType.STONE, 11));
    Assert.isTrue(inv.removeCount(ItemType.STONE, 4));
    Assert.isTrue(inv.has(ItemType.STONE, 6));
    Assert.isFalse(inv.has(ItemType.STONE, 7));
  }

  function testRemoveTooMuchFails() {
    var inv = owner.inventory;
    inv.addFresh(fresh(ItemType.COAL, 2));
    Assert.isFalse(inv.removeCount(ItemType.COAL, 5));
    Assert.isTrue(inv.has(ItemType.COAL, 2));
  }

  function testRemoveEmptiesSlot() {
    var inv = owner.inventory;
    inv.addFresh(fresh(ItemType.WOOD, 3));
    inv.removeCount(ItemType.WOOD, 3);
    Assert.equals(0, inv.slots.length);
    Assert.isTrue(inv.isEmpty());
  }

  function testActiveItem() {
    var inv = owner.inventory;
    Assert.isNull(inv.activeItem());
    inv.addFresh(fresh(ItemType.WOOD, 1));
    inv.addFresh(fresh(ItemType.STONE, 1));
    inv.activeSlot = 1;
    Assert.equals((ItemType.STONE : Int), (inv.activeItem().itemType : Int));
  }

  function testAddExistingReparents() {
    var inv = owner.inventory;
    var stray = fresh(ItemType.IRON_ORE, 2);
    Assert.isTrue(stray.inWorld());
    inv.addExisting(stray);
    Assert.equals(1, inv.slots.length);
    Assert.equals(owner, stray.parent);
    Assert.equals(0, stray.slot);
  }

  function testAddExistingMergesAndDestroys() {
    var inv = owner.inventory;
    inv.addFresh(fresh(ItemType.WOOD, 5));
    var destroyed:Array<Int> = [];
    inv.onDestroy = function(it) { destroyed.push(it.serial); };
    var incoming = fresh(ItemType.WOOD, 3);
    inv.addExisting(incoming);
    Assert.equals(1, inv.slots.length);
    Assert.equals(8, inv.slots[0].count);
    Assert.equals(1, destroyed.length);
    Assert.equals(incoming.serial, destroyed[0]);
  }
}
