package;

import utest.Assert;
import utest.Test;
import server.zone.Character;
import server.zone.ZoneSimulator;
import shared.world.MapData;
import shared.world.TileType;

class TestZoneSimulator extends Test {
  function buildMap():MapData {
    return MapData.filled(4, 4, TileType.GRASS);
  }

  function testTickAdvances() {
    var sim = new ZoneSimulator(buildMap());
    Assert.equals(0, sim.currentTick);
    sim.tick();
    sim.tick();
    Assert.equals(2, sim.currentTick);
  }

  function testSpawnRegistersEntity() {
    var sim = new ZoneSimulator(buildMap());
    var ch = new Character(1, "alice", null, 1, 1);
    sim.spawn(ch);
    Assert.equals(1, sim.entityCount());
    Assert.notNull(sim.entityById(1));
  }

  function testDespawnRemoves() {
    var sim = new ZoneSimulator(buildMap());
    sim.spawn(new Character(1, "alice", null, 1, 1));
    sim.despawn(1);
    Assert.equals(0, sim.entityCount());
    Assert.isNull(sim.entityById(1));
  }

  function testEntityAtFindsOccupant() {
    var sim = new ZoneSimulator(buildMap());
    sim.spawn(new Character(1, "alice", null, 2, 1));
    Assert.equals(1, sim.entityAt(2, 1).id);
    Assert.isNull(sim.entityAt(0, 0));
  }
}
