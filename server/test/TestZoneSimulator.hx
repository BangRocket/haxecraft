package;

import utest.Assert;
import utest.Test;
import server.zone.Character;
import server.zone.ZoneSimulator;
import shared.world.MapData;
import shared.world.TileType;
import shared.world.Direction;

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

  function testTickAppliesPendingMove() {
    var sim = new ZoneSimulator(buildMap());
    var ch = new Character(1, "alice", null, 1, 1);
    sim.spawn(ch);
    ch.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(2, ch.tileX);
    Assert.equals(1, ch.tileY);
    Assert.equals(-1, ch.pendingDir);             // intent consumed
    Assert.equals(1, sim.movesThisTick.length);
  }

  function testTickQueuesIntentThroughCooldown() {
    var sim = new ZoneSimulator(buildMap());
    var ch = new Character(1, "alice", null, 1, 1);
    sim.spawn(ch);

    ch.pendingDir = Direction.EAST;
    sim.tick();                                   // step to (2,1); cooldown begins
    Assert.equals(2, ch.tileX);

    ch.pendingDir = Direction.EAST;
    sim.tick();                                   // still cooling down — no step
    Assert.equals(2, ch.tileX);
    Assert.equals(0, sim.movesThisTick.length);
    Assert.equals(Direction.EAST, (ch.pendingDir : Direction));  // intent retained

    sim.tick();                                   // cooldown elapsed — queued step lands
    Assert.equals(3, ch.tileX);
    Assert.equals(1, sim.movesThisTick.length);
  }

  function testTickBlocksUnwalkableTile() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.WATER);
    var sim = new ZoneSimulator(map);
    var ch = new Character(1, "alice", null, 1, 1);
    sim.spawn(ch);
    ch.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(1, ch.tileX);                   // blocked, stays put
    Assert.equals(0, sim.movesThisTick.length);
  }

  function testTickBlocksOccupiedTile() {
    var sim = new ZoneSimulator(buildMap());
    var a = new Character(1, "alice", null, 1, 1);
    var b = new Character(2, "bob", null, 2, 1);
    sim.spawn(a);
    sim.spawn(b);
    a.pendingDir = Direction.EAST;                // (2,1) is occupied by bob
    sim.tick();
    Assert.equals(1, a.tileX);
    Assert.equals(0, sim.movesThisTick.length);
  }
}
