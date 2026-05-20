package;

import utest.Assert;
import utest.Test;
import server.zone.Mobile;
import server.zone.Item;
import server.zone.Serials;
import server.zone.SerialCounter;
import server.zone.ZoneSimulator;
import shared.item.ItemType;
import shared.world.MapData;
import shared.world.TileType;
import shared.world.Direction;

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

class TestZoneSimulator extends Test {
  function buildMap():MapData {
    return MapData.filled(4, 4, TileType.GRASS);
  }

  function makeSim():ZoneSimulator {
    return new ZoneSimulator(buildMap(), new Serials(new MemCounter()), 1);
  }

  function testTickAdvances() {
    var sim = makeSim();
    Assert.equals(0, sim.currentTick);
    sim.tick();
    sim.tick();
    Assert.equals(2, sim.currentTick);
  }

  function testSpawnRegistersMobile() {
    var sim = makeSim();
    var m = new Mobile(1, "alice", null, 1, 1);
    sim.spawn(m);
    Assert.equals(1, sim.mobileCount());
    Assert.notNull(sim.mobileBySerial(1));
  }

  function testDespawnRemoves() {
    var sim = makeSim();
    sim.spawn(new Mobile(1, "alice", null, 1, 1));
    sim.despawn(1);
    Assert.equals(0, sim.mobileCount());
    Assert.isNull(sim.mobileBySerial(1));
  }

  function testEntityAtFindsOccupant() {
    var sim = makeSim();
    sim.spawn(new Mobile(1, "alice", null, 2, 1));
    Assert.equals(1, sim.entityAt(2, 1).serial);
    Assert.isNull(sim.entityAt(0, 0));
  }

  function testTickAppliesPendingMove() {
    var sim = makeSim();
    var m = new Mobile(1, "alice", null, 1, 1);
    sim.spawn(m);
    m.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(2, m.tileX);
    Assert.equals(1, m.tileY);
    Assert.equals(-1, m.pendingDir);
    Assert.equals(1, sim.movesThisTick.length);
  }

  function testTickQueuesIntentThroughCooldown() {
    var sim = makeSim();
    var m = new Mobile(1, "alice", null, 1, 1);
    sim.spawn(m);

    m.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(2, m.tileX);

    m.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(2, m.tileX);
    Assert.equals(0, sim.movesThisTick.length);
    Assert.equals(Direction.EAST, (m.pendingDir : Direction));

    sim.tick();
    Assert.equals(3, m.tileX);
    Assert.equals(1, sim.movesThisTick.length);
  }

  function testTickBlocksUnwalkableTile() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.WATER);
    var sim = new ZoneSimulator(map, new Serials(new MemCounter()), 1);
    var m = new Mobile(1, "alice", null, 1, 1);
    sim.spawn(m);
    m.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(1, m.tileX);
    Assert.equals(0, sim.movesThisTick.length);
  }

  function testTickBlocksOccupiedTile() {
    var sim = makeSim();
    var a = new Mobile(1, "alice", null, 1, 1);
    var b = new Mobile(2, "bob", null, 2, 1);
    sim.spawn(a);
    sim.spawn(b);
    a.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(1, a.tileX);
    Assert.equals(0, sim.movesThisTick.length);
  }

  function testWorldObjectBlocksMove() {
    var sim = makeSim();
    sim.spawnItem(ItemType.CHEST, 1, 2, 1);
    var m = new Mobile(1, "alice", null, 1, 1);
    sim.spawn(m);
    m.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(1, m.tileX);
    Assert.equals(0, sim.movesThisTick.length);
  }

  function testGroundItemDoesNotBlockMove() {
    var sim = makeSim();
    sim.spawnItem(ItemType.WOOD, 3, 2, 1);
    var m = new Mobile(1, "alice", null, 1, 1);
    sim.spawn(m);
    m.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(2, m.tileX);
    Assert.equals(1, sim.movesThisTick.length);
  }

  function testWalkOverPicksUpGroundItem() {
    var sim = makeSim();
    var gi = sim.spawnItem(ItemType.WOOD, 4, 2, 1);
    var pickedSerial = gi.serial;
    var m = new Mobile(1, "alice", null, 1, 1);
    sim.spawn(m);
    m.pendingDir = Direction.EAST;
    sim.tick();
    Assert.equals(2, m.tileX);
    Assert.isTrue(m.inventory.has(ItemType.WOOD, 4));
    // The Item still lives in `sim.items` — its parent is now `m` (not in
    // the world), so itemAt returns null but the entry remains.
    var stillTracked = sim.items.get(pickedSerial);
    Assert.notNull(stillTracked);
    Assert.isFalse(stillTracked.inWorld());
    Assert.equals(1, sim.pickupsThisTick.length);
    Assert.equals(pickedSerial, sim.pickupsThisTick[0].worldItemSerial);
  }
}
