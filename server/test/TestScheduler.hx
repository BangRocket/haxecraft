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
