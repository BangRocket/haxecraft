# Tick Scheduler (Timers) — Design

**Date:** 2026-05-18
**Status:** Approved (design); pending implementation plan

## Context

After studying ModernUO (a modern Ultima Online server emulator), three of
its architectural patterns are worth adopting into haxecraft, as a three
sub-project arc:

1. **Tick scheduler (timers)** ← *this spec*
2. Unified `Mobile` / `Item` entity model + serials
3. Sector grid (spatial index)

This sub-project is first because it is small, independent of the other two,
and the next milestone (M3 — combat/skills/death) needs it most: swing timers,
monster respawn, and later M6 spell timers are all scheduled callbacks.

The zone today has no timer abstraction. Its timing is ad-hoc:

- `ZoneSimulator.currentTick` — the 10 Hz tick counter.
- `Character.nextMoveTick` — a per-entity move-cooldown field, checked inline
  when `tick()` pulls move intents.
- `ZoneSimulator.shouldFlushNow()` / `lastFlushTick` / `FLUSH_TICK_INTERVAL`
  (50 ticks) — the periodic DB flush; `Main.hx` calls
  `if (sim.shouldFlushNow()) sim.flushPositions()`.
- `ZoneSimulator.growTiles()` — runs **every tick**, advancing sapling/wheat
  growth on tiles near players.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Sub-project order | Timers first, then entity model, then sector grid |
| Time unit | Tick-based (the zone is a deterministic 10 Hz simulation) |
| Migration scope | Migrate genuine scheduled callbacks; leave cooldowns and per-tick logic |
| Scheduler structure | Bucket map keyed by absolute fire-tick |

**What is and isn't a timer.** Only *scheduled callbacks* — "run X at tick T" —
belong on the Scheduler. By that test:

- The **DB flush** is a genuine recurring timer → migrates onto the Scheduler.
- `Character.nextMoveTick` is a *cooldown gate* (a per-entity field comparison),
  not a fired callback → stays a field. The same applies to M3's future
  `nextSwingTick`.
- `growTiles()` runs every tick — it is per-frame logic, not an interval timer
  → stays a `tick()` call. (Converting it to a slower interval timer would
  change growth balance and is out of scope for an infrastructure change.)

So "migrate all timing" resolves to: build the Scheduler, migrate the flush,
leave the cooldown field and the per-tick growth scan alone. The Scheduler's
main payoff is the M3+ systems that will register their own timers.

## Scope

**In scope:** a `Scheduler` and a `ScheduledTimer` handle; wiring the Scheduler
into `ZoneSimulator`; migrating the DB flush onto it.

**Out of scope:** the unified entity model and sector grid (later sub-projects);
converting `growTiles` to an interval timer; any gateway timers (the gateway is
request/response and has no simulation tick); real-time (millisecond) timers.

## Section 1 — `Scheduler` and `ScheduledTimer`

Two new files, both pure (no I/O), unit-testable headlessly:

**`server/src/server/zone/ScheduledTimer.hx`** — the timer handle, its own
module so callers can `import server.zone.ScheduledTimer` cleanly:

- `fireTick:Int` — the absolute zone tick at which it next fires.
- `intervalTicks:Int` — `0` for a one-shot; `> 0` for a recurring timer.
- `callback:Void -> Void`.
- `cancelled:Bool` — set by `Scheduler.cancel`; checked at fire time.

**`server/src/server/zone/Scheduler.hx`** — the scheduler:

- Internal state: `now:Int` (the last tick advanced to) and
  `buckets:Map<Int, Array<ScheduledTimer>>` keyed by absolute fire-tick.
- `after(delayTicks:Int, callback:Void -> Void):ScheduledTimer` — schedule a
  one-shot for `now + delayTicks`.
- `every(intervalTicks:Int, callback:Void -> Void):ScheduledTimer` — schedule
  a recurring timer; first fire at `now + intervalTicks`.
- `cancel(timer:ScheduledTimer):Void` — sets `timer.cancelled`.
- `tick():Void` — increments `now`; takes the bucket for `now`, and for each
  timer in it (in insertion/FIFO order): skip if cancelled; otherwise run the
  callback; if recurring and not cancelled, advance `fireTick += intervalTicks`
  and re-bucket it.

Dispatch is O(1) in the number of timers per tick — no per-tick scan of all
timers.

## Section 2 — `ZoneSimulator` integration

- `ZoneSimulator` gains `public var scheduler:Scheduler`, created in its
  constructor (so M3+ handlers can register timers via `sim.scheduler`).
- `ZoneSimulator.tick()` calls `scheduler.tick()` once per zone tick (after the
  existing move/pickup processing, before or after `growTiles()` — order fixed
  in the plan; growth and timers do not interact).
- The DB flush migrates: the constructor registers
  `scheduler.every(FLUSH_TICK_INTERVAL, flushPositions)`. The members
  `shouldFlushNow()`, `markFlushed()`, and `lastFlushTick` are **deleted**;
  `FLUSH_TICK_INTERVAL` is kept only as the interval constant.
- `Main.hx` drops its `if (sim.shouldFlushNow()) sim.flushPositions();` line —
  the recurring timer drives the flush now.
- `growTiles()` and `Character.nextMoveTick` are untouched.

## Section 3 — Edge cases

- **No drift.** A recurring timer reschedules from its scheduled `fireTick`
  (`fireTick += intervalTicks`), never from the actual fire time.
- **Cancellation.** `cancel()` sets the flag; it is checked at fire time. A
  cancelled recurring timer is not re-bucketed, so it stops permanently.
- **Re-entrancy.** A callback may schedule new timers; future-tick buckets
  absorb them safely. The current tick's bucket is read into a local before
  firing, so a callback that schedules into the current tick does not get
  processed twice in the same `tick()`.
- **Callback exceptions.** Each callback runs inside a `try/catch`; a throwing
  timer logs and is otherwise contained — it never aborts `scheduler.tick()`
  or the zone loop, and subsequent timers in the bucket still fire.

## Section 4 — Testing

**Unit — `server/test/TestScheduler.hx`, pure, no zone:**

- a one-shot fires exactly once, at `now + delay`, not earlier;
- a recurring timer fires on every interval boundary;
- `cancel` stops a pending one-shot before it fires;
- `cancel` of a recurring timer stops all future fires;
- timers due on the same tick fire in scheduling (FIFO) order;
- a callback that schedules a new timer works (the new timer fires later);
- a callback that throws is contained — later timers in the same tick still
  fire and `tick()` returns normally.

**Integration:** `TestZoneLifecycle` already exercises the flush path
(walk → logout → position persisted); it passing confirms the flush, now
driven by a recurring timer, still works.

**Regression:** the full shared / client / integration suite stays green.

## Risks

- **Flush timing.** Driving the flush from a recurring timer rather than an
  inline tick check is behaviourally equivalent (same 50-tick cadence), but the
  plan must register the timer at construction so the first flush lands on
  schedule.
- **Tick-order coupling.** `scheduler.tick()` must be called once per zone
  tick from exactly one place (`ZoneSimulator.tick()`); the plan pins this so
  timers cannot double-fire or stall.

## Sub-project boundary

Complete when the `Scheduler` exists and is unit-tested, the DB flush runs as a
recurring scheduler timer, `Main.hx` no longer polls `shouldFlushNow`, and the
full suite is green. The unified entity model and sector grid follow as the
remaining two sub-projects of the UO-patterns arc.
