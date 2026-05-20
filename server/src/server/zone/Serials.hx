package server.zone;

/**
 * Global serial allocator. Mobiles draw from `0x00000001..0x3FFFFFFF`,
 * items from `0x40000000..0x7FFFFFFF` — the top bit (`0x40000000`)
 * discriminates kind, so a bare `Int` carries enough information to
 * route it correctly.
 *
 * Counters live in the DB via a `SerialCounter`; on `next*` the in-memory
 * value advances and is written back. The constructor primes the in-memory
 * values from the counter once.
 */
class Serials {
  public static inline var ITEM_BIT:Int = 0x40000000;
  public static inline var MOBILE_MAX:Int = 0x3FFFFFFF;
  public static inline var ITEM_MIN:Int = 0x40000000;
  public static inline var ITEM_MAX:Int = 0x7FFFFFFF;

  public static inline function isMobile(id:Int):Bool {
    return id > 0 && (id & ITEM_BIT) == 0;
  }

  public static inline function isItem(id:Int):Bool {
    return (id & ITEM_BIT) != 0 && id <= ITEM_MAX;
  }

  var counter:SerialCounter;
  var nextMobileN:Int;
  var nextItemN:Int;

  public function new(counter:SerialCounter) {
    this.counter = counter;
    this.nextMobileN = counter.loadMobileNext();
    this.nextItemN = counter.loadItemNext();
  }

  public function nextMobile():Int {
    var s = nextMobileN++;
    counter.storeMobileNext(nextMobileN);
    return s;
  }

  public function nextItem():Int {
    var s = nextItemN++;
    counter.storeItemNext(nextItemN);
    return s;
  }
}
