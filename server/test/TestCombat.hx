package;

import utest.Assert;
import utest.Test;
import server.zone.Mobile;
import server.zone.Serials;
import server.zone.SerialCounter;
import server.zone.ZoneSimulator;
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

class TestCombat extends Test {
  function makeSim():ZoneSimulator {
    return new ZoneSimulator(MapData.filled(16, 16, TileType.GRASS),
                             new Serials(new MemCounter()), 1);
  }

  function testAdjacentSwingAdvancesTimer() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 5, 4);
    sim.spawn(a); sim.spawn(b);
    a.attackTarget = b.serial;
    // Advance enough ticks for at least one swing to land
    // (SWING_TICKS_FIST = 15, so 20 ticks is comfortably past one).
    for (_ in 0...20) sim.tick();
    Assert.isTrue(a.nextSwingTick > 0, "swing timer advanced");
  }

  function testOutOfRangeDoesNotResolve() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 10, 4);          // 6 tiles away
    sim.spawn(a); sim.spawn(b);
    a.attackTarget = b.serial;
    for (_ in 0...20) sim.tick();
    Assert.equals(b.maxHp, b.hp);                     // untouched
    Assert.equals(0, a.nextSwingTick);                // timer never advanced
  }

  function testDeadTargetClearsAttackTarget() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 5, 4);
    sim.spawn(a); sim.spawn(b);
    b.hp = 0;
    a.attackTarget = b.serial;
    sim.tick();
    Assert.equals(0, a.attackTarget);
  }

  function testDeathStubResetsHp() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 5, 4);
    sim.spawn(a); sim.spawn(b);
    b.hp = 1;
    a.attackTarget = b.serial;
    // Many ticks — eventually a hit reduces b.hp <= 0 and the stub fires.
    // Worst case: 60% hit chance with 1-3 damage means ~99% chance a hit
    // lands inside 50 swing intervals = 750 ticks.
    var sawReset = false;
    var prevHp = b.hp;
    for (_ in 0...800) {
      sim.tick();
      if (b.hp == b.maxHp && prevHp < b.maxHp) { sawReset = true; break; }
      prevHp = b.hp;
    }
    Assert.isTrue(sawReset, "death stub fired and reset HP to maxHp");
  }

  function testTargetMovesOutOfRangeMidFight() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 5, 4);
    sim.spawn(a); sim.spawn(b);
    a.attackTarget = b.serial;
    for (_ in 0...20) sim.tick();
    var hpAfterEngagement = b.hp;
    // b walks well away; no more swings should land. HP regen may tick
    // upward but damage must not resume.
    b.tileX = 14;
    var swingTickWhenSeparated = a.nextSwingTick;
    for (_ in 0...30) sim.tick();
    Assert.isTrue(b.hp >= hpAfterEngagement, "no damage while out of range");
    Assert.equals(swingTickWhenSeparated, a.nextSwingTick);  // timer paused
  }
}
