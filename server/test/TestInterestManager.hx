package;

import utest.Assert;
import utest.Test;
import server.zone.Character;
import server.zone.InterestManager;
import server.zone.InterestDiff;

class TestInterestManager extends Test {
  static function ch(id:Int, x:Int, y:Int):Character {
    return new Character(id, 'e$id', null, x, y);
  }

  static function diffFor(diffs:Array<InterestDiff>, observerId:Int):Null<InterestDiff> {
    for (d in diffs) if (d.observerId == observerId) return d;
    return null;
  }

  function testFarApartNeverKnown() {
    var im = new InterestManager();
    var a = ch(1, 0, 0);
    var b = ch(2, 200, 0);
    var diffs = im.update([a, b]);
    Assert.equals(0, diffs.length);
    Assert.isFalse(im.knows(1, 2));
    Assert.isFalse(im.knows(2, 1));
  }

  function testEnterRangeProducesDiff() {
    var im = new InterestManager();
    var a = ch(1, 0, 0);
    var b = ch(2, 200, 0);
    im.update([a, b]);            // far: no diff
    b.tileX = 20;                 // now within SPAWN_EXTENT (32)
    var diffs = im.update([a, b]);
    var da = diffFor(diffs, 1);
    Assert.notNull(da);
    Assert.isTrue(da.entered.indexOf(2) >= 0);
    Assert.isTrue(im.knows(1, 2));
  }

  function testLeaveRangePastHysteresis() {
    var im = new InterestManager();
    var a = ch(1, 0, 0);
    var b = ch(2, 10, 0);
    im.update([a, b]);            // known
    b.tileX = 33;                 // inside 32..34 hysteresis band
    var d1 = im.update([a, b]);
    Assert.isNull(diffFor(d1, 1)); // still known, no left event
    b.tileX = 40;                 // past DESPAWN_EXTENT (34)
    var d2 = im.update([a, b]);
    var da = diffFor(d2, 1);
    Assert.notNull(da);
    Assert.isTrue(da.left.indexOf(2) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }

  function testHysteresisBandDoesNotEnter() {
    var im = new InterestManager();
    var a = ch(1, 0, 0);
    var b = ch(2, 33, 0);         // in the 32..34 band, never been known
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
    var a = ch(1, 0, 0);
    var b = ch(2, 10, 0);
    im.update([a, b]);            // mutually known
    var observers = im.forget(2);
    Assert.isTrue(observers.indexOf(1) >= 0);
    Assert.isFalse(im.knows(1, 2));
  }
}
