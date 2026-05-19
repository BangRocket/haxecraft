package server.zone;

/**
 * Tick-driven scheduler for one-shot and recurring callbacks. Pure — no I/O.
 * Timers are held in a bucket map keyed by their absolute fire-tick, so each
 * tick dispatches in O(1) of the number of timers, not a full scan.
 *
 * `tick()` must be called exactly once per zone tick.
 */
class Scheduler {
  var now:Int = 0;
  var buckets:Map<Int, Array<ScheduledTimer>> = new Map();

  public function new() {}

  /** Run `callback` once, `delayTicks` ticks from now (clamped to >= 1). */
  public function after(delayTicks:Int, callback:Void -> Void):ScheduledTimer {
    var d = delayTicks < 1 ? 1 : delayTicks;
    var t = new ScheduledTimer(now + d, 0, callback);
    bucket(t);
    return t;
  }

  /** Run `callback` every `intervalTicks` ticks (clamped to >= 1); the first
      fire is `intervalTicks` from now. */
  public function every(intervalTicks:Int, callback:Void -> Void):ScheduledTimer {
    var i = intervalTicks < 1 ? 1 : intervalTicks;
    var t = new ScheduledTimer(now + i, i, callback);
    bucket(t);
    return t;
  }

  public function cancel(timer:ScheduledTimer):Void {
    timer.cancelled = true;
  }

  /** Advance one tick and fire everything due. Call once per zone tick. */
  public function tick():Void {
    now++;
    var due = buckets.get(now);
    if (due == null) return;
    buckets.remove(now);   // snapshot — a callback scheduling into `now` re-buckets safely
    for (t in due) {
      if (t.cancelled) continue;
      try {
        t.callback();
      } catch (err:Dynamic) {
        Sys.println('[scheduler] timer callback threw: $err');
      }
      if (t.intervalTicks > 0 && !t.cancelled) {
        t.fireTick += t.intervalTicks;
        bucket(t);
      }
    }
  }

  function bucket(t:ScheduledTimer):Void {
    var arr = buckets.get(t.fireTick);
    if (arr == null) {
      arr = [];
      buckets.set(t.fireTick, arr);
    }
    arr.push(t);
  }
}
