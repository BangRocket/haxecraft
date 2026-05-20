package;

import utest.Assert;
import utest.Test;
import server.zone.Mobile;
import server.zone.SectorGrid;
import server.zone.InterestManager;
import server.zone.InterestDiff;

class TestInterestManager extends Test {
  static function mob(serial:Int, x:Int, y:Int):Mobile {
    return new Mobile(serial, 'm$serial', null, x, y);
  }

  static function diffFor(diffs:Array<InterestDiff>, observerId:Int):Null<InterestDiff> {
    for (d in diffs) if (d.observerId == observerId) return d;
    return null;
  }

  /** Move a mobile in the grid and update its tile fields together. */
  static function moveTo(grid:SectorGrid, m:Mobile, x:Int, y:Int):Void {
    grid.moveMobile(m, m.tileX, m.tileY, x, y);
    m.tileX = x; m.tileY = y;
  }

  /** Build a grid, register the mobiles, return both for later use. */
  static function build(mobiles:Array<Mobile>):{ grid:SectorGrid, list:Array<Mobile> } {
    var g = new SectorGrid(1024, 1024);
    for (m in mobiles) g.addMobile(m);
    return { grid: g, list: mobiles };
  }

  function testFarApartNeverKnown() {
    var s = build([mob(1, 0, 0), mob(2, 200, 0)]);
    var diffs = new InterestManager().update(s.grid, s.list.iterator());
    Assert.equals(0, diffs.length);
  }

  function testEnterRangeProducesDiff() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 200, 0);
    var s = build([a, b]);
    im.update(s.grid, s.list.iterator());
    moveTo(s.grid, b, 20, 0);
    var diffs = im.update(s.grid, s.list.iterator());
    var da = diffFor(diffs, 1);
    Assert.notNull(da);
    Assert.isTrue(da.entered.indexOf(2) >= 0);
    Assert.isTrue(im.knows(1, 2));
  }

  function testLeaveRangePastHysteresis() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 10, 0);
    var s = build([a, b]);
    im.update(s.grid, s.list.iterator());
    moveTo(s.grid, b, 33, 0);
    var d1 = im.update(s.grid, s.list.iterator());
    Assert.isNull(diffFor(d1, 1));
    moveTo(s.grid, b, 40, 0);
    var d2 = im.update(s.grid, s.list.iterator());
    var da = diffFor(d2, 1);
    Assert.notNull(da);
    Assert.isTrue(da.left.indexOf(2) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }

  function testHysteresisBandDoesNotEnter() {
    var s = build([mob(1, 0, 0), mob(2, 33, 0)]);
    var diffs = new InterestManager().update(s.grid, s.list.iterator());
    Assert.equals(0, diffs.length);
  }

  function testSelfAlwaysKnown() {
    Assert.isTrue(new InterestManager().knows(1, 1));
  }

  function testForgetReturnsObserversAndClears() {
    var im = new InterestManager();
    var s = build([mob(1, 0, 0), mob(2, 10, 0)]);
    im.update(s.grid, s.list.iterator());
    var observers = im.forget(2);
    Assert.isTrue(observers.indexOf(1) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }

  function testObserversOfReturnsKnowers() {
    var im = new InterestManager();
    var s = build([mob(1, 0, 0), mob(2, 10, 0), mob(3, 500, 0)]);
    im.update(s.grid, s.list.iterator());
    var obs = im.observersOf(1);
    Assert.isTrue(obs.indexOf(2) >= 0);
    Assert.isFalse(obs.indexOf(3) >= 0);
    Assert.isFalse(obs.indexOf(1) >= 0);
  }

  function testIsolatedPairsDoNotCross() {
    var im = new InterestManager();
    var a = mob(1, 100, 100);
    var b = mob(2, 105, 100);    // within range of a
    var c = mob(3, 800, 800);
    var d = mob(4, 805, 800);    // within range of c
    var s = build([a, b, c, d]);
    var diffs = im.update(s.grid, s.list.iterator());
    var da = diffFor(diffs, 1);
    Assert.notNull(da);
    Assert.isTrue(da.entered.indexOf(2) >= 0);   // a sees b
    Assert.isFalse(da.entered.indexOf(3) >= 0);  // a does NOT see c
    Assert.isFalse(da.entered.indexOf(4) >= 0);  // a does NOT see d
  }
}
