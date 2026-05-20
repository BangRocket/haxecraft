package;

import utest.Assert;
import utest.Test;
import server.zone.ZoneSimulator;
import server.zone.Mobile;
import server.zone.Item;
import server.zone.Serials;
import server.zone.SerialCounter;
import server.zone.Crafting;
import shared.world.MapData;
import shared.world.TileType;
import shared.item.ItemType;

/** In-memory counter double. */
private class MemCounter implements SerialCounter {
  public var mobile:Int = 1;
  public var item:Int = 0x40000000;
  public function new() {}
  public function loadMobileNext():Int return mobile;
  public function loadItemNext():Int return item;
  public function storeMobileNext(v:Int):Void { mobile = v; }
  public function storeItemNext(v:Int):Void { item = v; }
}

class TestCrafting extends Test {
  function makeSim():ZoneSimulator {
    return new ZoneSimulator(MapData.filled(8, 8, TileType.GRASS),
                             new Serials(new MemCounter()), 1);
  }

  function makeActor(sim:ZoneSimulator):Mobile {
    var m = new Mobile(sim.serials.nextMobile(), "a", null, 4, 4);
    sim.spawn(m);
    return m;
  }

  function giveFresh(sim:ZoneSimulator, m:Mobile, t:ItemType, count:Int):Void {
    var it = new Item(sim.serials.nextItem(), t, count);
    m.inventory.addFresh(it);
  }

  function testCraftRequiresAStation() {
    var sim = makeSim();
    var m = makeActor(sim);
    giveFresh(sim, m, ItemType.WOOD, 50);
    Assert.isFalse(Crafting.craft(sim, m, 1));
  }

  function testCraftConsumesInputsAndProducesOutput() {
    var sim = makeSim();
    var m = makeActor(sim);
    giveFresh(sim, m, ItemType.WOOD, 50);
    sim.spawnItem(ItemType.WORKBENCH, 1, 5, 4);
    Assert.isTrue(Crafting.craft(sim, m, 1));
    Assert.isTrue(m.inventory.has(ItemType.WORKBENCH, 1));
    Assert.isTrue(m.inventory.has(ItemType.WOOD, 30));
  }

  function testCraftFailsWithoutEnoughResources() {
    var sim = makeSim();
    var m = makeActor(sim);
    giveFresh(sim, m, ItemType.WOOD, 5);
    sim.spawnItem(ItemType.WORKBENCH, 1, 5, 4);
    Assert.isFalse(Crafting.craft(sim, m, 1));
    Assert.isTrue(m.inventory.has(ItemType.WOOD, 5));
  }

  function testPlaceFurnitureConsumesAndPlaces() {
    var sim = makeSim();
    var m = makeActor(sim);
    giveFresh(sim, m, ItemType.CHEST, 1);
    m.inventory.activeSlot = 0;
    var obj = Crafting.place(sim, m, 5, 4);
    Assert.notNull(obj);
    var nObjs = 0;
    for (_ in sim.worldObjects()) nObjs++;
    Assert.equals(1, nObjs);
    Assert.isFalse(m.inventory.has(ItemType.CHEST, 1));
  }

  function testPlaceFailsOnOccupiedTile() {
    var sim = makeSim();
    var m = makeActor(sim);
    giveFresh(sim, m, ItemType.CHEST, 1);
    m.inventory.activeSlot = 0;
    sim.spawnItem(ItemType.OVEN, 1, 5, 4);
    Assert.isNull(Crafting.place(sim, m, 5, 4));
  }
}
