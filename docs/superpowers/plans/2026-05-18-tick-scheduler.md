# Tick Scheduler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a tick-driven scheduler for one-shot and recurring callbacks, and migrate the zone's periodic DB flush onto it.

**Architecture:** A pure, unit-testable `Scheduler` holds timers in a bucket map keyed by absolute fire-tick; `ScheduledTimer` is the cancellation handle. `ZoneSimulator` owns a `Scheduler`, advances it once per `tick()`, and registers the DB flush as a recurring timer — replacing the inline `shouldFlushNow()` poll.

**Tech Stack:** Haxe 4.3, HashLink (HLC native on Apple Silicon), utest.

**Spec:** `docs/superpowers/specs/2026-05-18-tick-scheduler-design.md`

---

## File Structure

**New files:**
- `server/src/server/zone/ScheduledTimer.hx` — the timer handle (own module so it imports cleanly).
- `server/src/server/zone/Scheduler.hx` — the tick scheduler.
- `server/test/TestScheduler.hx` — unit tests.

**Modified files:**
- `server/test/TestMain.hx` — register `TestScheduler`.
- `server/src/server/zone/ZoneSimulator.hx` — own + drive a `Scheduler`; migrate the flush; drop `shouldFlushNow`/`markFlushed`/`lastFlushTick`.
- `server/src/server/zone/Main.hx` — drop the inline `shouldFlushNow()` flush call.

This is the first of three sub-projects in the UO-patterns arc; the entity model and sector grid are separate plans.

---

## Task 1: `Scheduler` + `ScheduledTimer`

**Files:**
- Create: `server/src/server/zone/ScheduledTimer.hx`, `server/src/server/zone/Scheduler.hx`
- Create: `server/test/TestScheduler.hx`
- Modify: `server/test/TestMain.hx`

- [ ] **Step 1: Write the failing tests**

Create `server/test/TestScheduler.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Scheduler;

class TestScheduler extends Test {
  function testOneShotFiresOnceAtDelay() {
    var s = new Scheduler();
    var fired = 0;
    s.after(3, () -> fired++);
    s.tick();
    s.tick();
    Assert.equals(0, fired);   // ticks 1,2 — not due
    s.tick();
    Assert.equals(1, fired);   // tick 3 — fires
    s.tick();
    s.tick();
    Assert.equals(1, fired);   // never again
  }

  function testRecurringFiresEveryInterval() {
    var s = new Scheduler();
    var fired = 0;
    s.every(2, () -> fired++);
    for (_ in 0...6) s.tick();  // ticks 1..6
    Assert.equals(3, fired);    // fired at 2, 4, 6
  }

  function testCancelStopsOneShot() {
    var s = new Scheduler();
    var fired = 0;
    var t = s.after(3, () -> fired++);
    s.cancel(t);
    for (_ in 0...5) s.tick();
    Assert.equals(0, fired);
  }

  function testCancelStopsRecurring() {
    var s = new Scheduler();
    var fired = 0;
    var t = s.every(2, () -> fired++);
    s.tick();
    s.tick();                   // tick 2 — fires once
    Assert.equals(1, fired);
    s.cancel(t);
    for (_ in 0...6) s.tick();
    Assert.equals(1, fired);    // no further fires
  }

  function testSameTickFifoOrder() {
    var s = new Scheduler();
    var order:Array<String> = [];
    s.after(1, () -> order.push("a"));
    s.after(1, () -> order.push("b"));
    s.after(1, () -> order.push("c"));
    s.tick();
    Assert.equals("a,b,c", order.join(","));
  }

  function testCallbackCanScheduleNewTimer() {
    var s = new Scheduler();
    var fired = 0;
    s.after(1, () -> s.after(1, () -> fired++));
    s.tick();                   // tick 1: first fires, schedules a new one
    Assert.equals(0, fired);
    s.tick();                   // tick 2: the new one fires
    Assert.equals(1, fired);
  }

  function testThrowingCallbackIsContained() {
    var s = new Scheduler();
    var fired = 0;
    s.after(1, () -> { throw "boom"; });
    s.after(1, () -> fired++);
    s.tick();                   // first throws, second still fires
    Assert.equals(1, fired);
  }
}
```

Register it in `server/test/TestMain.hx` — add after the `TestInterestManager` line:

```haxe
    r.addCase(new TestInterestManager());
    r.addCase(new TestScheduler());
```

- [ ] **Step 2: Run the build to verify it fails**

Run: `./build_native.sh server-test`
Expected: FAIL — compile error, `server.zone.Scheduler` not found.

- [ ] **Step 3: Create `ScheduledTimer`**

Create `server/src/server/zone/ScheduledTimer.hx`:

```haxe
package server.zone;

/** A scheduled callback. The object is its own cancellation handle. */
class ScheduledTimer {
  public var fireTick:Int;
  public var intervalTicks:Int;   // 0 = one-shot; > 0 = recurring
  public var callback:Void -> Void;
  public var cancelled:Bool = false;

  public function new(fireTick:Int, intervalTicks:Int, callback:Void -> Void) {
    this.fireTick = fireTick;
    this.intervalTicks = intervalTicks;
    this.callback = callback;
  }
}
```

- [ ] **Step 4: Create `Scheduler`**

Create `server/src/server/zone/Scheduler.hx`:

```haxe
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `./build_native.sh server-test && ./bin/server-test`
Expected: `TestScheduler` — all 7 cases green. (`TestLoginFlow` / `TestZoneLifecycle` / `TestZoneInterest` / `TestZoneChat` error without a live server — not this task's concern; verified under a live server in Task 2.)

- [ ] **Step 6: Commit**

```bash
git add server/src/server/zone/ScheduledTimer.hx server/src/server/zone/Scheduler.hx server/test/TestScheduler.hx server/test/TestMain.hx
git commit -m "feat(zone): tick scheduler for one-shot + recurring callbacks

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Wire the `Scheduler` into `ZoneSimulator`; migrate the flush

**Files:**
- Modify: `server/src/server/zone/ZoneSimulator.hx`
- Modify: `server/src/server/zone/Main.hx`

- [ ] **Step 1: Replace the `lastFlushTick` field with a `scheduler` field**

In `server/src/server/zone/ZoneSimulator.hx`, replace:

```haxe
  public var lastFlushTick:Int = 0;
  public static inline var FLUSH_TICK_INTERVAL:Int = 50;  // 5s at 10 Hz
```

with:

```haxe
  public static inline var FLUSH_TICK_INTERVAL:Int = 50;  // 5s at 10 Hz

  /** Tick scheduler — drives the DB flush and (later) combat/respawn timers. */
  public var scheduler(default, null):Scheduler = new Scheduler();
```

- [ ] **Step 2: Register the flush timer in the constructor**

In `ZoneSimulator`'s constructor, replace:

```haxe
  public function new(map:MapData, ?characterDal:server.db.CharacterDal,
      ?tileDal:server.db.ZoneTileDal) {
    this.map = map;
    this.characterDal = characterDal;
    this.tileDal = tileDal;
  }
```

with:

```haxe
  public function new(map:MapData, ?characterDal:server.db.CharacterDal,
      ?tileDal:server.db.ZoneTileDal) {
    this.map = map;
    this.characterDal = characterDal;
    this.tileDal = tileDal;
    scheduler.every(FLUSH_TICK_INTERVAL, flushPositions);
  }
```

- [ ] **Step 3: Delete `shouldFlushNow` and `markFlushed`; drop the `markFlushed` call**

In `ZoneSimulator`, delete these two methods entirely:

```haxe
  public function shouldFlushNow():Bool {
    return (currentTick - lastFlushTick) >= FLUSH_TICK_INTERVAL;
  }

  public function markFlushed():Void {
    lastFlushTick = currentTick;
  }
```

Then in `flushPositions()`, delete its final line:

```haxe
    markFlushed();
```

(`flushPositions` keeps its per-character save loop and its `try/catch`; it just no longer marks a flush tick.)

- [ ] **Step 4: Drive the scheduler from `tick()`**

In `ZoneSimulator.tick()`, the method currently ends with a call to `growTiles();`. Add a `scheduler.tick()` call immediately after it, as the last statement of `tick()`:

```haxe
    growTiles();
    scheduler.tick();
  }
```

- [ ] **Step 5: Remove the inline flush poll from `Main.hx`**

In `server/src/server/zone/Main.hx`, in the per-tick block, delete this line:

```haxe
        if (sim.shouldFlushNow()) sim.flushPositions();
```

The recurring scheduler timer now drives the flush.

- [ ] **Step 6: Build the zone**

Run: `./build_native.sh zone server-test`
Expected: `clang -> bin/zone` and `clang -> bin/server-test`, exit 0.

- [ ] **Step 7: Run the integration suite**

First clear any stale server process (a leftover zone on port 7778 makes the suite test stale code):

```bash
pkill -f 'bin/zone' ; pkill -f 'bin/gateway' ; sleep 1
./run-integration.sh
```

Expected: `ALL TESTS OK` — `TestScheduler` green, and `TestZoneLifecycle` still passes (it walks, logs out, and reconnects to confirm the position persisted — which exercises the flush, now driven by the recurring timer).

- [ ] **Step 8: Run the shared + client suites for regression**

Run: `make test && ./build_native.sh client-test && ./bin/client-test`
Expected: both `ALL TESTS OK`.

- [ ] **Step 9: Commit**

```bash
git add server/src/server/zone/ZoneSimulator.hx server/src/server/zone/Main.hx
git commit -m "feat(zone): drive the DB flush from the tick scheduler

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes

**Spec coverage:**
- §1 `Scheduler` / `ScheduledTimer` (`after`, `every`, `cancel`, `tick`, bucket map, FIFO, recurring re-bucket) → Task 1.
- §2 `ZoneSimulator` integration (`scheduler` field, constructor registers the flush via `every`, `tick()` drives it, `shouldFlushNow`/`markFlushed`/`lastFlushTick` deleted, `Main.hx` poll removed) → Task 2.
- §3 edge cases: no drift → `fireTick += intervalTicks` (Task 1 Step 4); cancellation → `cancelled` flag checked at fire and before re-bucket; re-entrancy → `buckets.remove(now)` snapshot + `after`/`every` clamp delays to ≥ 1 so a same-tick schedule lands in the next bucket; callback exceptions → per-callback `try/catch`. Re-entrancy and containment are tested by `testCallbackCanScheduleNewTimer` and `testThrowingCallbackIsContained`.
- §4 testing: 7 unit cases → Task 1; integration via `TestZoneLifecycle` + regression → Task 2 Steps 7–8.

**Placeholder scan:** none — every step has concrete code or an exact command.

**Type consistency:** `ScheduledTimer` fields (`fireTick`, `intervalTicks`, `callback`, `cancelled`) are used identically in `Scheduler`. `Scheduler` API — `after(Int, Void->Void):ScheduledTimer`, `every(Int, Void->Void):ScheduledTimer`, `cancel(ScheduledTimer)`, `tick():Void` — matches the test usage (Task 1) and the `ZoneSimulator` usage (`scheduler.every(FLUSH_TICK_INTERVAL, flushPositions)`, `scheduler.tick()`) in Task 2. `flushPositions` is `Void->Void`, valid as an `every` callback.

**Out of scope:** the unified `Mobile`/`Item` entity model and the sector grid (later sub-projects); converting `growTiles` to an interval timer; `nextMoveTick` (stays a cooldown field).
