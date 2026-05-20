package;

import utest.Assert;
import utest.Test;
import server.zone.Mobile;
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

  function testFarApartNeverKnown() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 200, 0);
    var diffs = im.update([a, b]);
    Assert.equals(0, diffs.length);
    Assert.isFalse(im.knows(1, 2));
    Assert.isFalse(im.knows(2, 1));
  }

  function testEnterRangeProducesDiff() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 200, 0);
    im.update([a, b]);
    b.tileX = 20;
    var diffs = im.update([a, b]);
    var da = diffFor(diffs, 1);
    Assert.notNull(da);
    Assert.isTrue(da.entered.indexOf(2) >= 0);
    Assert.isTrue(im.knows(1, 2));
  }

  function testLeaveRangePastHysteresis() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 10, 0);
    im.update([a, b]);
    b.tileX = 33;
    var d1 = im.update([a, b]);
    Assert.isNull(diffFor(d1, 1));
    b.tileX = 40;
    var d2 = im.update([a, b]);
    var da = diffFor(d2, 1);
    Assert.notNull(da);
    Assert.isTrue(da.left.indexOf(2) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }

  function testHysteresisBandDoesNotEnter() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 33, 0);
    var diffs = im.update([a, b]);
    Assert.equals(0, diffs.length);
    Assert.isFalse(im.knows(1, 2));
  }

  function testSelfAlwaysKnown() {
    var im = new InterestManager();
    Assert.isTrue(im.knows(1, 1));
  }

  function testForgetReturnsObserversAndClears() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 10, 0);
    im.update([a, b]);
    var observers = im.forget(2);
    Assert.isTrue(observers.indexOf(1) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }

  function testObserversOfReturnsKnowers() {
    var im = new InterestManager();
    var a = mob(1, 0, 0);
    var b = mob(2, 10, 0);
    var c = mob(3, 500, 0);
    im.update([a, b, c]);
    var obs = im.observersOf(1);
    Assert.isTrue(obs.indexOf(2) >= 0);
    Assert.isFalse(obs.indexOf(3) >= 0);
    Assert.isFalse(obs.indexOf(1) >= 0);
  }
}
