package;

import utest.Assert;
import utest.Test;
import server.zone.ZoneSimulator;
import server.zone.Mobile;
import server.zone.Item;
import server.zone.Serials;
import server.zone.SerialCounter;
import server.zone.TileInteraction;
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

class TestTileInteraction extends Test {
  function makeSim(?map:MapData):ZoneSimulator {
    if (map == null) map = MapData.filled(4, 4, TileType.GRASS);
    return new ZoneSimulator(map, new Serials(new MemCounter()), 1);
  }

  function actor(sim:ZoneSimulator, item:ItemType):Mobile {
    var m = new Mobile(sim.serials.nextMobile(), "a", null, 1, 1);
    sim.spawn(m);
    var it = new Item(sim.serials.nextItem(), item, 9);
    m.inventory.addFresh(it);
    m.inventory.activeSlot = 0;
    return m;
  }

  function groundItemsArr(sim:ZoneSimulator):Array<Item> {
    return [for (it in sim.groundItems()) it];
  }

  function testGemAxeFellsTreeInOneHit() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.TREE);
    var sim = makeSim(map);
    var m = actor(sim, ItemType.GEM_AXE);
    Assert.isTrue(TileInteraction.apply(sim, m, 2, 1));
    Assert.equals((TileType.GRASS : Int), sim.map.tileAt(2, 1));
  }

  function testWrongToolDoesNothing() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.TREE);
    var sim = makeSim(map);
    var m = actor(sim, ItemType.GEM_PICKAXE);
    Assert.isFalse(TileInteraction.apply(sim, m, 2, 1));
    Assert.equals((TileType.TREE : Int), sim.map.tileAt(2, 1));
  }

  function testHoeTurnsGrassToFarmland() {
    var sim = makeSim();
    var m = actor(sim, ItemType.WOOD_HOE);
    Assert.isTrue(TileInteraction.apply(sim, m, 2, 1));
    Assert.equals((TileType.FARMLAND : Int), sim.map.tileAt(2, 1));
  }

  function testPlantSeedsConsumesAndGrowsWheat() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.FARMLAND);
    var sim = makeSim(map);
    var m = actor(sim, ItemType.SEEDS);
    Assert.isTrue(TileInteraction.apply(sim, m, 2, 1));
    Assert.equals((TileType.WHEAT : Int), sim.map.tileAt(2, 1));
    Assert.isTrue(m.inventory.has(ItemType.SEEDS, 8));
  }

  function testMiningRockTakesSeveralHits() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.ROCK);
    var sim = makeSim(map);
    var m = actor(sim, ItemType.WOOD_PICKAXE);
    TileInteraction.apply(sim, m, 2, 1);
    Assert.equals((TileType.ROCK : Int), sim.map.tileAt(2, 1));
    for (_ in 0...6) TileInteraction.apply(sim, m, 2, 1);
    Assert.equals((TileType.DIRT : Int), sim.map.tileAt(2, 1));
  }

  function testFlowerDropsTwoFlowers() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.FLOWER);
    var sim = makeSim(map);
    var m = actor(sim, ItemType.WOOD_SHOVEL);
    Assert.isTrue(TileInteraction.apply(sim, m, 2, 1));
    Assert.equals((TileType.GRASS : Int), sim.map.tileAt(2, 1));
    var gi = groundItemsArr(sim);
    Assert.equals(1, gi.length);
    Assert.equals((ItemType.FLOWER : Int), (gi[0].itemType : Int));
    Assert.equals(2, gi[0].count);
  }
}
