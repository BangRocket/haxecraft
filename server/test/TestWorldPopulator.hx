package;

import utest.Assert;
import utest.Test;
import server.zone.ZoneSimulator;
import server.zone.WorldPopulator;
import shared.world.MapData;
import shared.world.TileType;

class TestWorldPopulator extends Test {
  function makeSim():ZoneSimulator {
    // All-walkable map large enough for the spawn-centred placement.
    return new ZoneSimulator(MapData.filled(1024, 1024, TileType.GRASS));
  }

  function testPopulatesObjectsAndItems() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    Assert.equals(6, sim.worldObjects.length);   // all 6 furniture on all-grass
    Assert.equals(40, sim.groundItems.length);
  }

  function testDeterministic() {
    var a = makeSim(); WorldPopulator.populate(a);
    var b = makeSim(); WorldPopulator.populate(b);
    Assert.equals(a.groundItems.length, b.groundItems.length);
    for (i in 0...a.groundItems.length) {
      Assert.equals(a.groundItems[i].tileX, b.groundItems[i].tileX);
      Assert.equals(a.groundItems[i].tileY, b.groundItems[i].tileY);
      Assert.equals((a.groundItems[i].itemType : Int), (b.groundItems[i].itemType : Int));
      Assert.equals(a.groundItems[i].count, b.groundItems[i].count);
    }
  }

  function testPlacedOnWalkableTiles() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    for (o in sim.worldObjects) Assert.isTrue(sim.map.isWalkable(o.tileX, o.tileY));
    for (gi in sim.groundItems) Assert.isTrue(sim.map.isWalkable(gi.tileX, gi.tileY));
  }

  function testIdsUnique() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    var oids = new Map<Int, Bool>();
    for (o in sim.worldObjects) { Assert.isFalse(oids.exists(o.id)); oids.set(o.id, true); }
    var iids = new Map<Int, Bool>();
    for (gi in sim.groundItems) { Assert.isFalse(iids.exists(gi.id)); iids.set(gi.id, true); }
  }

  function testItemsDoNotOverlapObjects() {
    var sim = makeSim();
    WorldPopulator.populate(sim);
    for (gi in sim.groundItems) Assert.isFalse(sim.objectAt(gi.tileX, gi.tileY));
  }
}
