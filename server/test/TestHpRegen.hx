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

class TestHpRegen extends Test {
  function makeSim():ZoneSimulator {
    return new ZoneSimulator(MapData.filled(4, 4, TileType.GRASS),
                             new Serials(new MemCounter()), 1);
  }

  function testRegensOneHpEveryFortyTicks() {
    var sim = makeSim();
    var m = new Mobile(1, "a", null, 1, 1);
    sim.spawn(m);
    m.hp = 30;                                 // 20 below maxHp 50
    // 40 ticks -> first regen fires (registered as scheduler.every(40, ...)).
    for (_ in 0...40) sim.tick();
    Assert.equals(31, m.hp);
    for (_ in 0...40) sim.tick();
    Assert.equals(32, m.hp);
  }

  function testFullHpDoesNotChange() {
    var sim = makeSim();
    var m = new Mobile(1, "a", null, 1, 1);
    sim.spawn(m);
    Assert.equals(m.maxHp, m.hp);
    for (_ in 0...200) sim.tick();
    Assert.equals(m.maxHp, m.hp);
  }
}
