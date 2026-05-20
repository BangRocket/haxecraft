package;

import utest.Assert;
import utest.Test;
import server.zone.Serials;
import server.zone.SerialCounter;

/** In-memory test double for the persistent counter, used by TestSerials. */
class MemCounter implements SerialCounter {
  public var mobile:Int;
  public var item:Int;
  public function new(mobile:Int = 1, item:Int = 0x40000000) {
    this.mobile = mobile;
    this.item = item;
  }
  public function loadMobileNext():Int return mobile;
  public function loadItemNext():Int return item;
  public function storeMobileNext(v:Int):Void { mobile = v; }
  public function storeItemNext(v:Int):Void { item = v; }
}

class TestSerials extends Test {
  function testIsMobileIsItem() {
    Assert.isTrue(Serials.isMobile(1));
    Assert.isTrue(Serials.isMobile(0x3FFFFFFF));
    Assert.isFalse(Serials.isMobile(0x40000000));
    Assert.isFalse(Serials.isMobile(0));            // zero is neither

    Assert.isTrue(Serials.isItem(0x40000000));
    Assert.isTrue(Serials.isItem(0x7FFFFFFF));
    Assert.isFalse(Serials.isItem(1));
    Assert.isFalse(Serials.isItem(0));
  }

  function testAllocatesInRanges() {
    var s = new Serials(new MemCounter(1, 0x40000000));
    var m1 = s.nextMobile();
    var m2 = s.nextMobile();
    Assert.equals(1, m1);
    Assert.equals(2, m2);
    Assert.isTrue(Serials.isMobile(m1));

    var i1 = s.nextItem();
    var i2 = s.nextItem();
    Assert.equals(0x40000000, i1);
    Assert.equals(0x40000001, i2);
    Assert.isTrue(Serials.isItem(i1));
  }

  function testSeedsFromCounter() {
    var c = new MemCounter(100, 0x40000050);
    var s = new Serials(c);
    Assert.equals(100, s.nextMobile());
    Assert.equals(0x40000050, s.nextItem());
  }

  function testWritesBackOnAlloc() {
    var c = new MemCounter(5, 0x40000000);
    var s = new Serials(c);
    s.nextMobile();   // returns 5; counter advances to 6
    s.nextMobile();   // returns 6; counter advances to 7
    s.nextItem();     // returns 0x40000000; counter advances to 0x40000001
    Assert.equals(7, c.mobile);
    Assert.equals(0x40000001, c.item);
  }
}
