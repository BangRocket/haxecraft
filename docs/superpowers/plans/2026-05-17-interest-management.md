# Interest Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Filter zone entity broadcast so each player only hears about entities within a ~64-tile area of interest, with spawn/despawn firing as entities enter and leave each other's view.

**Architecture:** A pure, unit-testable `InterestManager` holds a per-observer "known set" of entity IDs and, each zone tick, recomputes every observer's AOI (O(n²) Chebyshev distance with hysteresis) and diffs it to produce enter/leave events. The zone loop sends `EntitySpawn`/`EntityDespawn` from those diffs, and `MoveIntentHandler.broadcastMoves` sends each `EntityMove` only to observers who know the mover.

**Tech Stack:** Haxe 4.3, HashLink (HLC native on Apple Silicon), utest.

**Spec:** `docs/superpowers/specs/2026-05-17-interest-management-design.md`

---

## File Structure

**New files:**
- `server/src/server/zone/InterestDiff.hx` — the per-observer diff typedef, its own module so `Main.hx` (same package) and the test resolve it cleanly (Task 1).
- `server/src/server/zone/InterestManager.hx` — interest state + per-tick diff (Task 1).
- `server/test/TestInterestManager.hx` — unit tests for `InterestManager` (Task 1).

**Modified files:**
- `server/test/TestMain.hx` — register `TestInterestManager` and (Task 3) `TestZoneInterest`.
- `server/src/server/zone/MoveIntentHandler.hx` — take an `InterestManager`; filter the move broadcast (Task 2).
- `server/src/server/zone/EnterZoneHandler.hx` — drop the full existing-entity sync loop (Task 2).
- `server/src/server/zone/Main.hx` — create the `InterestManager`, run `update` each tick, broadcast diffs, filter the disconnect despawn (Task 2).
- `client/src/headless/HeadlessClient.hx` — add `drainFrames` for multi-client test observation (Task 3).

**New test file (Task 3):**
- `server/test/TestZoneInterest.hx` — two-client integration test.

No wire-protocol change: `EntitySpawn` / `EntityMove` / `EntityDespawn` are reused as-is. No client (game) change.

---

## Task 1: `InterestManager` core + unit tests

**Files:**
- Create: `server/src/server/zone/InterestDiff.hx`
- Create: `server/src/server/zone/InterestManager.hx`
- Create: `server/test/TestInterestManager.hx`
- Modify: `server/test/TestMain.hx`

- [ ] **Step 1: Write the failing tests**

Create `server/test/TestInterestManager.hx`:

```haxe
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
```

Register it in `server/test/TestMain.hx` — add after the `TestZoneSimulator` line:

```haxe
    r.addCase(new TestZoneSimulator());
    r.addCase(new TestInterestManager());
```

- [ ] **Step 2: Run the build to verify it fails**

Run: `./build_native.sh server-test`
Expected: FAIL — compile error, `server.zone.InterestManager` / `server.zone.InterestDiff` not found.

- [ ] **Step 3: Create the `InterestDiff` typedef**

Create `server/src/server/zone/InterestDiff.hx`:

```haxe
package server.zone;

/** Per-observer interest change for one tick. */
typedef InterestDiff = { observerId:Int, entered:Array<Int>, left:Array<Int> };
```

- [ ] **Step 4: Implement `InterestManager`**

Create `server/src/server/zone/InterestManager.hx`:

```haxe
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

  static inline function chebyshev(a:Character, b:Character):Int {
    var dx = a.tileX - b.tileX; if (dx < 0) dx = -dx;
    var dy = a.tileY - b.tileY; if (dy < 0) dy = -dy;
    return dx > dy ? dx : dy;
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `./build_native.sh server-test && ./bin/server-test`
Expected: `TestInterestManager` — all 6 cases green. (`TestLoginFlow` / `TestZoneLifecycle` need a running server and will fail here; they are verified under a live server in Task 3. The `TestInterestManager` cases are what this task confirms.)

- [ ] **Step 6: Commit**

```bash
git add server/src/server/zone/InterestDiff.hx server/src/server/zone/InterestManager.hx server/test/TestInterestManager.hx server/test/TestMain.hx
git commit -m "feat(zone): InterestManager — per-observer AOI with hysteresis

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Wire `InterestManager` into the zone

This task atomically switches the zone from broadcast-to-everyone to interest-filtered. It touches three files together because any half-applied state is broken (duplicate or missing spawns).

**Files:**
- Modify: `server/src/server/zone/MoveIntentHandler.hx`
- Modify: `server/src/server/zone/EnterZoneHandler.hx`
- Modify: `server/src/server/zone/Main.hx`

- [ ] **Step 1: Give `MoveIntentHandler` an `InterestManager` and filter the move broadcast**

In `server/src/server/zone/MoveIntentHandler.hx`, replace the class fields and constructor:

```haxe
class MoveIntentHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler) {
    this.sim = sim;
    this.enterHandler = enterHandler;
  }
```

with:

```haxe
class MoveIntentHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;
  var interest:InterestManager;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler, interest:InterestManager) {
    this.sim = sim;
    this.enterHandler = enterHandler;
    this.interest = interest;
  }
```

Then in `broadcastMoves`, replace the inner send loop:

```haxe
      for (e in sim.allEntities()) {
        if (e.conn != null && e.conn.alive) {
          e.conn.sendFrame(MsgType.ENTITY_MOVE, bytes);
        }
      }
```

with:

```haxe
      for (e in sim.allEntities()) {
        if (e.conn != null && e.conn.alive && interest.knows(e.id, mv.entityId)) {
          e.conn.sendFrame(MsgType.ENTITY_MOVE, bytes);
        }
      }
```

- [ ] **Step 2: Drop the full existing-entity sync from `EnterZoneHandler`**

In `server/src/server/zone/EnterZoneHandler.hx`, delete this block (it currently follows the self-echo spawn — the per-tick interest update now handles syncing existing entities both ways):

```haxe
    // Sync existing entities to this client + broadcast the new entity to existing clients.
    for (other in sim.allEntities()) {
      if (other.id == runtime.id) continue;
      var osp = new shared.proto.MsgEntitySpawn();
      osp.entityId = other.id; osp.name = other.name;
      osp.tileX = other.tileX; osp.tileY = other.tileY;
      var oo = new haxe.io.BytesOutput(); osp.serialize(oo);
      conn.sendFrame(shared.proto.MsgType.ENTITY_SPAWN, oo.getBytes());
      if (other.conn != null && other.conn.alive) {
        other.conn.sendFrame(shared.proto.MsgType.ENTITY_SPAWN, spBytes);
      }
    }
```

The method now ends right after the self-echo `conn.sendFrame(shared.proto.MsgType.ENTITY_SPAWN, spBytes);` line. (`spBytes` is still used by that self-echo — keep it.)

- [ ] **Step 3: Create the `InterestManager` in `Main` and pass it to `MoveIntentHandler`**

In `server/src/server/zone/Main.hx`, replace:

```haxe
    var sim = new ZoneSimulator(map, characterDal);
    var enterHandler = new EnterZoneHandler(characterDal, sim);
    var moveHandler = new MoveIntentHandler(sim, enterHandler);
```

with:

```haxe
    var sim = new ZoneSimulator(map, characterDal);
    var interest = new InterestManager();
    var enterHandler = new EnterZoneHandler(characterDal, sim);
    var moveHandler = new MoveIntentHandler(sim, enterHandler, interest);
```

- [ ] **Step 4: Run the interest update each tick and broadcast the diffs**

In `server/src/server/zone/Main.hx`, in the tick block, replace:

```haxe
      if (now >= nextTickAt) {
        sim.tick();
        moveHandler.broadcastMoves();
        if (sim.shouldFlushNow()) sim.flushPositions();
```

with:

```haxe
      if (now >= nextTickAt) {
        sim.tick();
        moveHandler.broadcastMoves();
        var entityList = [for (e in sim.allEntities()) e];
        broadcastInterestDiffs(sim, interest.update(entityList));
        if (sim.shouldFlushNow()) sim.flushPositions();
```

Then add this static helper to the `Main` class (after `main()`):

```haxe
  static function broadcastInterestDiffs(sim:ZoneSimulator, diffs:Array<InterestDiff>):Void {
    for (d in diffs) {
      var observer = sim.entityById(d.observerId);
      if (observer == null || observer.conn == null || !observer.conn.alive) continue;
      for (id in d.entered) {
        var e = sim.entityById(id);
        if (e == null) continue;
        var sp = new shared.proto.MsgEntitySpawn();
        sp.entityId = e.id;
        sp.name = e.name;
        sp.tileX = e.tileX;
        sp.tileY = e.tileY;
        var o = new haxe.io.BytesOutput(); sp.serialize(o);
        observer.conn.sendFrame(shared.proto.MsgType.ENTITY_SPAWN, o.getBytes());
      }
      for (id in d.left) {
        var dp = new shared.proto.MsgEntityDespawn();
        dp.entityId = id;
        var o = new haxe.io.BytesOutput(); dp.serialize(o);
        observer.conn.sendFrame(shared.proto.MsgType.ENTITY_DESPAWN, o.getBytes());
      }
    }
  }
```

- [ ] **Step 5: Filter the disconnect despawn through `interest.forget`**

In `server/src/server/zone/Main.hx`, in the dead-connection branch, replace:

```haxe
              // Broadcast despawn to remaining entities BEFORE removing.
              var dp = new shared.proto.MsgEntityDespawn();
              dp.entityId = owned;
              var dpOut = new haxe.io.BytesOutput(); dp.serialize(dpOut);
              var dpBytes = dpOut.getBytes();
              for (other in sim.allEntities()) {
                if (other.id == owned) continue;
                if (other.conn != null && other.conn.alive) {
                  other.conn.sendFrame(shared.proto.MsgType.ENTITY_DESPAWN, dpBytes);
                }
              }

              sim.despawn(owned);
```

with:

```haxe
              // Despawn for every observer that currently knows this entity.
              var dp = new shared.proto.MsgEntityDespawn();
              dp.entityId = owned;
              var dpOut = new haxe.io.BytesOutput(); dp.serialize(dpOut);
              var dpBytes = dpOut.getBytes();
              for (obsId in interest.forget(owned)) {
                var obs = sim.entityById(obsId);
                if (obs != null && obs.conn != null && obs.conn.alive) {
                  obs.conn.sendFrame(shared.proto.MsgType.ENTITY_DESPAWN, dpBytes);
                }
              }

              sim.despawn(owned);
```

- [ ] **Step 6: Build the zone to verify it compiles**

Run: `./build_native.sh zone`
Expected: `clang -> bin/zone`, exit 0.

- [ ] **Step 7: Run the integration suite to confirm single-client behavior is intact**

Run: `./run-integration.sh`
Expected: `ALL TESTS OK` — `TestZoneLifecycle` still passes (a lone client always knows itself, so walk + persist is unaffected), and `TestInterestManager` is green.

- [ ] **Step 8: Commit**

```bash
git add server/src/server/zone/MoveIntentHandler.hx server/src/server/zone/EnterZoneHandler.hx server/src/server/zone/Main.hx
git commit -m "feat(zone): filter entity broadcast through InterestManager

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Multi-client integration test

**Files:**
- Modify: `client/src/headless/HeadlessClient.hx`
- Create: `server/test/TestZoneInterest.hx`
- Modify: `server/test/TestMain.hx`

- [ ] **Step 1: Add `drainFrames` to `HeadlessClient`**

In `client/src/headless/HeadlessClient.hx`, add this method after `move` (before `close`):

```haxe
  /** Read whatever zone frames arrive within `durationS`, return them all.
      Used by tests to observe spawns/moves of other entities. **/
  public function drainFrames(durationS:Float):Array<{msgType:Int, payload:Bytes}> {
    var out:Array<{msgType:Int, payload:Bytes}> = [];
    var deadline = haxe.Timer.stamp() + durationS;
    while (haxe.Timer.stamp() < deadline) {
      zone.setTimeout(0.05);
      try {
        var f = FrameCodec.readFrame(zone.input);
        out.push({ msgType: (f.msgType : Int), payload: f.payload });
      } catch (_:haxe.io.Eof) {
        break;
      } catch (_:Dynamic) {
        // read timeout — keep polling until the deadline
      }
    }
    return out;
  }
```

- [ ] **Step 2: Write the integration test**

Create `server/test/TestZoneInterest.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;
import shared.world.Direction;
import shared.proto.MsgType;
import shared.proto.MsgEntitySpawn;
import shared.proto.MsgEntityMove;
import haxe.io.BytesInput;
import HeadlessClient;

class TestZoneInterest extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var userA:String = "test_interest_a";
  var userB:String = "test_interest_b";
  var pw:String = "test_pw";

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    accountDal = new AccountDal(db);
    for (u in [userA, userB]) {
      db.exec("DELETE FROM characters WHERE name = ?", [u]);
      db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      accountDal.create(u, PasswordHash.hash(pw));
    }
  }

  function teardownClass() {
    if (db != null) {
      for (u in [userA, userB]) {
        db.exec("DELETE FROM characters WHERE name = ?", [u]);
        db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      }
      db.close();
    }
  }

  // PRECONDITION: gateway + zone running on 127.0.0.1:7777/7778.

  function plant(name:String, x:Int, y:Int):Void {
    db.exec("UPDATE characters SET tile_x = ?, tile_y = ? WHERE name = ?", [x, y, name]);
  }

  // Log in (autocreates the character), returns the connected client.
  function loginClient(user:String):HeadlessClient {
    var c = new HeadlessClient();
    c.connectGateway();
    Assert.isTrue(c.login(user, pw));
    return c;
  }

  static function sawSpawn(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>, entityId:Int):Bool {
    for (f in frames) if (f.msgType == (MsgType.ENTITY_SPAWN : Int)) {
      if (MsgEntitySpawn.deserialize(new BytesInput(f.payload)).entityId == entityId) return true;
    }
    return false;
  }

  static function sawMove(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>, entityId:Int):Bool {
    for (f in frames) if (f.msgType == (MsgType.ENTITY_MOVE : Int)) {
      if (MsgEntityMove.deserialize(new BytesInput(f.payload)).entityId == entityId) return true;
    }
    return false;
  }

  // Try each cardinal once; return true on the first accepted move.
  static function moveOnce(c:HeadlessClient):Bool {
    for (d in [Direction.EAST, Direction.WEST, Direction.NORTH, Direction.SOUTH]) {
      if (c.move(d)) return true;
      Sys.sleep(0.25);
    }
    return false;
  }

  function testNearbyPlayersSeeEachOther() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 308, 512);          // 8 tiles apart — inside SPAWN_EXTENT
    cA.enterZone();
    cB.enterZone();

    Assert.isTrue(sawSpawn(cA.drainFrames(0.6), cB.entityId), "A should see B spawn");
    Assert.isTrue(sawSpawn(cB.drainFrames(0.6), cA.entityId), "B should see A spawn");

    Assert.isTrue(moveOnce(cA), "expected an accepted move for A");
    Assert.isTrue(sawMove(cB.drainFrames(0.6), cA.entityId), "B should see A's move");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }

  function testDistantPlayersAreFiltered() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 800, 512);          // 500 tiles apart — far beyond AOI
    cA.enterZone();
    cB.enterZone();

    Assert.isFalse(sawSpawn(cA.drainFrames(0.6), cB.entityId), "A must not see distant B");

    Assert.isTrue(moveOnce(cA), "expected an accepted move for A");
    Assert.isFalse(sawMove(cB.drainFrames(0.6), cA.entityId), "B must not see distant A's move");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }
}
```

Register it in `server/test/TestMain.hx` — add after the `TestZoneLifecycle` line:

```haxe
    r.addCase(new TestZoneLifecycle());
    r.addCase(new TestZoneInterest());
```

- [ ] **Step 3: Run the full integration suite**

Run: `./run-integration.sh`
Expected: `ALL TESTS OK` — `TestZoneInterest` both cases green, `TestInterestManager` green, and all prior server tests (`TestZoneLifecycle`, `TestLoginFlow`, etc.) still pass.

- [ ] **Step 4: Run the shared + client unit suites for regression**

Run: `make test && ./build_native.sh client-test && ./bin/client-test`
Expected: both `ALL TESTS OK` — no regression (these are untouched, but `HeadlessClient` is shared with `server-test`, so this confirms nothing else broke).

- [ ] **Step 5: Commit**

```bash
git add client/src/headless/HeadlessClient.hx server/test/TestZoneInterest.hx server/test/TestMain.hx
git commit -m "test(zone): two-client integration test for interest filtering

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes

**Spec coverage:**
- §1 `InterestManager` (state, `SPAWN_EXTENT`/`DESPAWN_EXTENT`, `update`/`knows`/`forget`, hysteresis) → Task 1.
- §2 zone loop integration (simplified `EnterZoneHandler` keeping the self-echo, per-tick `update` + diff broadcast, `broadcastMoves` filtered by `knows`, disconnect via `forget`) → Task 2.
- §3 edge cases: self-visibility → `knows` returns true for `observerId == entityId` and `update` skips `other.id == obs.id` (Task 1), tested by `testSelfAlwaysKnown`; mid-move enter spawns at current tile → `broadcastInterestDiffs` reads the entity's live `tileX`/`tileY` (Task 2); map edges → distance check naturally yields fewer entities, no special code.
- §4 testing: unit tests → Task 1; two-client integration (near sees, far filtered) → Task 3; regression `TestZoneLifecycle` → Task 2 Step 7 and Task 3 Step 3.

**Tick ordering (spec Risks):** Task 2 Step 4 places `moveHandler.broadcastMoves()` before `interest.update(...)`, so moves broadcast on the previous tick's known-sets and interest updates after — the explicit order the spec calls for.

**Placeholder scan:** none — every step has concrete code or an exact command.

**Type consistency:** `InterestDiff` is `{observerId, entered, left}` in Task 1 and consumed with those exact fields in `broadcastInterestDiffs` (Task 2). `InterestManager` constructor is `new()` (no args) — matched in Task 2 Step 3. `MoveIntentHandler` constructor becomes `(sim, enterHandler, interest)` in Task 2 Step 1 and is called with exactly those three args in Step 3. `drainFrames` returns `Array<{msgType:Int, payload:Bytes}>` (Task 3 Step 1) and the test's `sawSpawn`/`sawMove` consume `{msgType, payload}` (Step 2). `Character` constructor `(id, name, conn, tileX, tileY)` matches existing usage.

**Out of scope:** chat, emotes, CI, bots (remaining M2 sub-projects); spatial-grid optimization (the O(n²) recompute sits behind the `InterestManager` interface for a later swap).
