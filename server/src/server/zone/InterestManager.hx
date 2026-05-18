package server.zone;

/**
 * Tracks, per observer entity, the set of entity IDs that observer currently
 * knows about. Each tick `update` recomputes every observer's area of
 * interest (square Chebyshev range, O(n^2)) and diffs it against the previous
 * tick to produce enter/leave events.
 *
 * Hysteresis: an entity enters the known-set at distance <= SPAWN_EXTENT and
 * is dropped only past DESPAWN_EXTENT, so an entity walking the AOI boundary
 * does not flicker.
 */
class InterestManager {
  public static inline var SPAWN_EXTENT = 32;
  public static inline var DESPAWN_EXTENT = 34;

  // observerId -> set of known entity IDs (Map<Int,Bool> used as a set).
  var known:Map<Int, Map<Int,Bool>> = new Map();

  public function new() {}

  /** Recompute interest for every entity; return one diff per changed observer. */
  public function update(entities:Array<Character>):Array<InterestDiff> {
    var diffs:Array<InterestDiff> = [];
    for (obs in entities) {
      var prev = known.get(obs.id);
      if (prev == null) prev = new Map();
      var nextSet = new Map<Int,Bool>();
      var entered:Array<Int> = [];
      var left:Array<Int> = [];
      for (other in entities) {
        if (other.id == obs.id) continue;
        var wasKnown = prev.exists(other.id);
        var d = chebyshev(obs, other);
        var nowKnown = wasKnown ? (d <= DESPAWN_EXTENT) : (d <= SPAWN_EXTENT);
        if (nowKnown) {
          nextSet.set(other.id, true);
          if (!wasKnown) entered.push(other.id);
        } else if (wasKnown) {
          left.push(other.id);
        }
      }
      known.set(obs.id, nextSet);
      if (entered.length > 0 || left.length > 0) {
        diffs.push({ observerId: obs.id, entered: entered, left: left });
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
      IDs that had known it (so the caller can despawn it for them). */
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

  /** Observer IDs whose known-set currently contains `entityId` (excludes self). */
  public function observersOf(entityId:Int):Array<Int> {
    var out:Array<Int> = [];
    for (obsId in known.keys()) {
      if (obsId == entityId) continue;
      var s = known.get(obsId);
      if (s.exists(entityId)) out.push(obsId);
    }
    return out;
  }

  static inline function chebyshev(a:Character, b:Character):Int {
    var dx = a.tileX - b.tileX; if (dx < 0) dx = -dx;
    var dy = a.tileY - b.tileY; if (dy < 0) dy = -dy;
    return dx > dy ? dx : dy;
  }
}
