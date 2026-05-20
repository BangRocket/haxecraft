package;

import utest.Assert;
import utest.Test;
import server.zone.Item;
import server.zone.Serials;
import server.zone.SerialCounter;
import server.zone.ZoneSimulator;
import server.zone.WorldPopulator;
import shared.world.MapData;
import shared.world.TileType;

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

class TestWorldPopulator extends Test {
  function makeSim():ZoneSimulator {
    return new ZoneSimulator(MapData.filled(1024, 1024, TileType.GRASS),
                             new Serials(new MemCounter()), 1);
  }

  function worldObjects(sim:ZoneSimulator):Array<Item> {
    return [for (it in sim.worldObjects()) it];
  }

  function groundItems(sim:ZoneSimulator):Array<Item> {
    return [for (it in sim.groundItems()) it];
  }

  function testPopulatesObjectsAndItems() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    Assert.equals(6, worldObjects(sim).length);
    Assert.equals(40, groundItems(sim).length);
  }

  function testDeterministic() {
    var a = makeSim(); WorldPopulator.populate(a);
    var b = makeSim(); WorldPopulator.populate(b);
    var ag = groundItems(a);
    var bg = groundItems(b);
    Assert.equals(ag.length, bg.length);
    for (i in 0...ag.length) {
      Assert.equals(ag[i].tileX, bg[i].tileX);
      Assert.equals(ag[i].tileY, bg[i].tileY);
      Assert.equals((ag[i].itemType : Int), (bg[i].itemType : Int));
      Assert.equals(ag[i].count, bg[i].count);
    }
  }

  function testPlacedOnWalkableTiles() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    for (o in worldObjects(sim)) Assert.isTrue(sim.map.isWalkable(o.tileX, o.tileY));
    for (gi in groundItems(sim)) Assert.isTrue(sim.map.isWalkable(gi.tileX, gi.tileY));
  }

  function testSerialsUnique() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    var seen = new Map<Int, Bool>();
    for (it in sim.items) {
      Assert.isFalse(seen.exists(it.serial));
      seen.set(it.serial, true);
    }
  }

  function testItemsDoNotOverlapObjects() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    for (gi in groundItems(sim)) Assert.isFalse(sim.objectAt(gi.tileX, gi.tileY));
  }
}
