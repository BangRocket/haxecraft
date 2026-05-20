package server.zone;

/**
 * Tracks, per observer mobile, the set of mobile serials that observer
 * currently knows about. Each tick `update` recomputes every observer's
 * area of interest (square Chebyshev range, O(n^2)) and diffs it against
 * the previous tick to produce enter/leave events.
 *
 * Hysteresis: a mobile enters the known-set at distance <= SPAWN_EXTENT and
 * is dropped only past DESPAWN_EXTENT, so a mobile walking the AOI boundary
 * does not flicker.
 */
class InterestManager {
  public static inline var SPAWN_EXTENT = 32;
  public static inline var DESPAWN_EXTENT = 34;

  // observerSerial -> set of known mobile serials (Map<Int,Bool> used as a set).
  var known:Map<Int, Map<Int,Bool>> = new Map();

  public function new() {}

  /** Recompute interest for every mobile; return one diff per changed observer. */
  public function update(mobiles:Array<Mobile>):Array<InterestDiff> {
    var diffs:Array<InterestDiff> = [];
    for (obs in mobiles) {
      var prev = known.get(obs.serial);
      if (prev == null) prev = new Map();
      var nextSet = new Map<Int,Bool>();
      var entered:Array<Int> = [];
      var left:Array<Int> = [];
      for (other in mobiles) {
        if (other.serial == obs.serial) continue;
        var wasKnown = prev.exists(other.serial);
        var d = chebyshev(obs, other);
        var nowKnown = wasKnown ? (d <= DESPAWN_EXTENT) : (d <= SPAWN_EXTENT);
        if (nowKnown) {
          nextSet.set(other.serial, true);
          if (!wasKnown) entered.push(other.serial);
        } else if (wasKnown) {
          left.push(other.serial);
        }
      }
      known.set(obs.serial, nextSet);
      if (entered.length > 0 || left.length > 0) {
        diffs.push({ observerId: obs.serial, entered: entered, left: left });
      }
    }
    return diffs;
  }

  /** True if the observer currently knows the entity (or is that entity). */
  public function knows(observerId:Int, entityId:Int):Bool {
    if (observerId == entityId) return true;
    var s = known.get(observerId);
    return s != null && s.exists(entityId);
  }

  /** Drop an entity as observer and from every known-set; return the observer
      serials that had known it (so the caller can despawn it for them). */
  public function forget(entityId:Int):Array<Int> {
    var observersWhoKnew:Array<Int> = [];
    known.remove(entityId);
    for (obsId in known.keys()) {
      var s = known.get(obsId);
      if (s.exists(entityId)) {
        observersWhoKnew.push(obsId);
        s.remove(entityId);
      }
    }
    return observersWhoKnew;
  }

  /** Observer serials whose known-set currently contains `entityId` (excludes self). */
  public function observersOf(entityId:Int):Array<Int> {
    var out:Array<Int> = [];
    for (obsId in known.keys()) {
      if (obsId == entityId) continue;
      var s = known.get(obsId);
      if (s.exists(entityId)) out.push(obsId);
    }
    return out;
  }

  static inline function chebyshev(a:Mobile, b:Mobile):Int {
    var dx = a.tileX - b.tileX; if (dx < 0) dx = -dx;
    var dy = a.tileY - b.tileY; if (dy < 0) dy = -dy;
    return dx > dy ? dx : dy;
  }
}
