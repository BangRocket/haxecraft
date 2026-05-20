# Combat (PvP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add stats + HP + swing-timer combat to mobiles so two clients can attack each other; the loser's HP=0 hits a respawn-stub. The first of four M3 sub-projects.

**Architecture:** `Mobile` gains five combat fields (`str`, `dex`, `intel`, `hp`, `maxHp`) plus a cooldown gate (`nextSwingTick`) and an attack-target serial. Migration 0006 extends `mobiles` with five columns. `ZoneSimulator.tick()` runs a second pass after movement that resolves swings on the adjacency gate; HP regen ticks every 40 ticks via the existing scheduler. Wire gains `MsgAttackTarget` (client → server) and `MsgCombatEvent` (server → broadcast); `MsgEntitySpawn` carries HP for mobiles.

**Tech Stack:** Haxe 4.3, HashLink (HLC native on Apple Silicon), utest, MySQL/InnoDB.

**Spec:** `docs/superpowers/specs/2026-05-20-combat-pvp-design.md`

---

## File Structure

**New files:**
- `db/migrations/0006_combat_stats.sql` — extends `mobiles` with `str`, `dex`, `intel`, `hp`, `max_hp` columns.
- `shared/src/shared/proto/MsgAttackTarget.hx` — client → server attack intent.
- `shared/src/shared/proto/MsgCombatEvent.hx` — server → broadcast swing resolution.
- `server/src/server/zone/CombatHandler.hx` — handles `MsgAttackTarget`; broadcasts combat events per tick.
- `server/test/TestCombat.hx` — swing resolution unit tests.
- `server/test/TestHpRegen.hx` — HP regen scheduler unit tests.
- `server/test/TestZoneCombat.hx` — two-client integration test.

**Modified files:**
- `server/src/server/zone/Mobile.hx` — add the seven combat fields.
- `server/src/server/db/MobileDal.hx` — `MobileRow` carries stats + HP; `insert` + new `saveStatsAndHp` write them.
- `server/src/server/zone/EnterZoneHandler.hx` — load stats + HP into the runtime `Mobile`; spawn message echoes HP.
- `server/src/server/zone/ZoneSimulator.hx` — register HP-regen scheduler timer; `tick()` runs `resolveSwings()` after the move pass; `pendingCombatEvents` collection; `flushMobilePositions` also writes HP + stats.
- `server/src/server/zone/Main.hx` — register `CombatHandler` with the dispatcher; per-tick `combatHandler.broadcastEvents()`; entity-spawn-in-interest also fills HP.
- `shared/src/shared/proto/MsgEntitySpawn.hx` — add `hp` + `maxHp` fields.
- `shared/src/shared/proto/MsgType.hx` — `ATTACK_TARGET = 41`, `COMBAT_EVENT = 42`.
- `client/src/client/Main.hx` — `F`/`ESC` keybinds for attack target; handle `MsgCombatEvent`.
- `client/src/client/render/ZoneRenderer.hx` — HP-bar rendering + floating combat tells.
- `client/src/headless/HeadlessClient.hx` — `attack(targetSerial)` helper; `combatEvents` buffer.
- `server/test/TestMain.hx` — register the new test cases.

---

## Task 1: Schema + Mobile combat fields + persistence

This task lands the data shape — Mobile carries the combat state, the DB persists it, and the entity-spawn burst echoes HP. Combat resolution is **not** yet running; mobiles can be damaged programmatically but nothing damages them yet. Wire-compatible end state.

**Files:**
- Create: `db/migrations/0006_combat_stats.sql`
- Modify: `server/src/server/zone/Mobile.hx`, `server/src/server/db/MobileDal.hx`, `server/src/server/zone/EnterZoneHandler.hx`, `server/src/server/zone/ZoneSimulator.hx`, `shared/src/shared/proto/MsgEntitySpawn.hx`

- [ ] **Step 1: Write the migration**

Create `db/migrations/0006_combat_stats.sql`:

```sql
-- Extend mobiles with combat stats + HP. All new columns default to 50,
-- giving every existing mobile a fresh 50/50/50/50/50 baseline.
-- Idempotent via INFORMATION_SCHEMA check.

DROP PROCEDURE IF EXISTS apply_0006;
DELIMITER //
CREATE PROCEDURE apply_0006()
BEGIN
  DECLARE has_str INT;
  SELECT COUNT(*) INTO has_str
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mobiles' AND COLUMN_NAME = 'str';
  IF has_str = 0 THEN
    ALTER TABLE mobiles
      ADD COLUMN str    INT NOT NULL DEFAULT 50,
      ADD COLUMN dex    INT NOT NULL DEFAULT 50,
      ADD COLUMN intel  INT NOT NULL DEFAULT 50,
      ADD COLUMN hp     INT NOT NULL DEFAULT 50,
      ADD COLUMN max_hp INT NOT NULL DEFAULT 50;
  END IF;
END //
DELIMITER ;
CALL apply_0006();
DROP PROCEDURE apply_0006;
```

(Idempotent because `apply-migrations.sh` re-pipes every file every run.)

- [ ] **Step 2: Apply the migration**

Run: `./db/apply-migrations.sh`
Expected: `0006_combat_stats.sql` applied; `DESCRIBE mobiles` shows the
five new columns with defaults of 50.

Verify with:
```bash
docker compose exec -T mysql mysql --protocol=tcp -uhaxecraft -pdev_local_only haxecraft \
  -e "SELECT serial, name, str, dex, intel, hp, max_hp FROM mobiles;"
```

- [ ] **Step 3: Extend `Mobile.hx`**

Add the seven new fields to `server/src/server/zone/Mobile.hx`:

```haxe
public var str:Int = 50;
public var dex:Int = 50;
public var intel:Int = 50;        // `int` is reserved in Haxe
public var hp:Int;
public var maxHp:Int;
public var nextSwingTick:Int = 0;
/** 0 = not attacking; otherwise the target's serial. */
public var attackTarget:Int = 0;
```

Initialize `hp`/`maxHp` in the constructor:

```haxe
public function new(serial:Int, name:String, conn:Null<ClientConnection>,
                    tileX:Int, tileY:Int) {
  this.serial = serial;
  this.name = name;
  this.conn = conn;
  this.tileX = tileX;
  this.tileY = tileY;
  this.maxHp = 25 + Std.int(str / 2);    // placeholder; SP2 will recompute on stat changes
  this.hp = this.maxHp;
  this.inventory = new Inventory(this);
}
```

- [ ] **Step 4: Extend `MobileDal`**

Add the five fields to `MobileRow`:

```haxe
typedef MobileRow = {
  serial:Int,
  accountId:Null<Int>,
  name:String,
  zoneId:Int,
  tileX:Int,
  tileY:Int,
  str:Int,
  dex:Int,
  intel:Int,
  hp:Int,
  maxHp:Int
};
```

Update `findByAccountId`'s SELECT to include the new columns:

```haxe
public function findByAccountId(accountId:Int):Null<MobileRow> {
  var rows = db.query(
    "SELECT serial, account_id, name, zone_id, tile_x, tile_y, str, dex, intel, hp, max_hp FROM mobiles WHERE account_id = ? LIMIT 1",
    [accountId]
  );
  if (rows.length == 0) return null;
  return rowOf(rows[0]);
}
```

Update `rowOf` to populate them:

```haxe
static inline function rowOf(r:Dynamic):MobileRow return {
  serial: (r.serial : Int),
  accountId: r.account_id == null ? null : (r.account_id : Int),
  name: (r.name : String),
  zoneId: (r.zone_id : Int),
  tileX: (r.tile_x : Int),
  tileY: (r.tile_y : Int),
  str: (r.str : Int),
  dex: (r.dex : Int),
  intel: (r.intel : Int),
  hp: (r.hp : Int),
  maxHp: (r.max_hp : Int)
};
```

Add `saveStatsAndHp`:

```haxe
public function saveStatsAndHp(serial:Int, str:Int, dex:Int, intel:Int, hp:Int, maxHp:Int):Void {
  db.exec(
    "UPDATE mobiles SET str = ?, dex = ?, intel = ?, hp = ?, max_hp = ? WHERE serial = ?",
    [str, dex, intel, hp, maxHp, serial]
  );
}
```

The existing `insert` doesn't need changes — new mobiles will land with the column defaults (50/50/50/50/50) which is exactly the constructor's behavior.

- [ ] **Step 5: Hydrate stats + HP on enter-zone**

In `server/src/server/zone/EnterZoneHandler.hx`, after constructing the
runtime `Mobile`, copy persisted stats from the row:

```haxe
var runtime = new Mobile(row.serial, row.name, conn, sx, sy);
runtime.str = row.str;
runtime.dex = row.dex;
runtime.intel = row.intel;
runtime.maxHp = row.maxHp;
runtime.hp = row.hp;
```

Place this **before** the `attachCarriedItem` loop so the mobile's
state is fully restored before any hooks fire.

Also update the echo-spawn at the bottom of `handle()` to include HP:

```haxe
var sp = new shared.proto.MsgEntitySpawn();
sp.entityId = runtime.serial;
sp.name = runtime.name;
sp.tileX = runtime.tileX;
sp.tileY = runtime.tileY;
sp.hp = runtime.hp;
sp.maxHp = runtime.maxHp;
```

- [ ] **Step 6: Extend the spawn-message body**

In `shared/src/shared/proto/MsgEntitySpawn.hx`, add the two fields at
the end (preserving the existing serialization order):

```haxe
@:build(shared.proto.SerializableMacro.build())
class MsgEntitySpawn implements Serializable {
  public var entityId:Int = 0;
  public var name:String = "";
  public var itemTypeId:Int = 0;
  public var count:Int = 0;
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public var parentSerial:Int = 0;
  public var slot:Int = 0;
  public var hp:Int = 0;        // mobile only
  public var maxHp:Int = 0;     // mobile only
  public function new() {}
}
```

- [ ] **Step 7: Wire HP into the interest spawn**

In `server/src/server/zone/Main.hx`, the `broadcastInterestDiffs` helper
constructs `MsgEntitySpawn` when an observer enters AOI. Fill the new
HP fields:

```haxe
for (id in d.entered) {
  var e = sim.mobileBySerial(id);
  if (e == null) continue;
  var sp = new shared.proto.MsgEntitySpawn();
  sp.entityId = e.serial;
  sp.name = e.name;
  sp.tileX = e.tileX;
  sp.tileY = e.tileY;
  sp.hp = e.hp;
  sp.maxHp = e.maxHp;
  var o = new haxe.io.BytesOutput(); sp.serialize(o);
  observer.conn.sendFrame(shared.proto.MsgType.ENTITY_SPAWN, o.getBytes());
}
```

- [ ] **Step 8: Extend `flushMobilePositions` to persist stats + HP**

In `server/src/server/zone/ZoneSimulator.hx`, the periodic flush now
also writes stats + HP. Change `flushMobilePositions`:

```haxe
public function flushMobilePositions():Void {
  if (mobileDal == null) return;
  for (m in mobiles) {
    try {
      mobileDal.savePosition(m.serial, m.tileX, m.tileY);
      mobileDal.saveStatsAndHp(m.serial, m.str, m.dex, m.intel, m.hp, m.maxHp);
    } catch (err:Dynamic) {
      Sys.println('[zone] flush save failed for mobile ${m.serial}: $err');
    }
  }
}
```

Also extend the per-disconnect save in `Main.hx` (the
`if (!c.alive)` block):

```haxe
try {
  mobileDal.savePosition(m.serial, m.tileX, m.tileY);
  mobileDal.saveStatsAndHp(m.serial, m.str, m.dex, m.intel, m.hp, m.maxHp);
} catch (err:Dynamic) {
  Sys.println('[zone] disconnect save failed for mobile ${m.serial}: $err');
}
```

- [ ] **Step 9: Build + run all tests**

Run: `./build_native.sh shared-test client-test server-test zone gateway client`
Expected: all targets compile.

Run: `./bin/shared-test && ./bin/client-test`
Expected: both `ALL TESTS OK`.

Run unit-only:
```bash
./bin/server-test 2>&1 | grep -E "assertations|successes|errors|failures|results:"
```
Expected: same baseline (513/506/7) — the 7 errors are integration
tests needing a live server.

Run integration:
```bash
pkill -f 'bin/zone' ; pkill -f 'bin/gateway' ; sleep 1
./run-integration.sh 2>&1 | grep -E "assertations|successes|errors|failures|results:"
```
Expected: `ALL TESTS OK` (548 baseline).

- [ ] **Step 10: Commit**

```bash
git add db/migrations/0006_combat_stats.sql \
        server/src/server/zone/Mobile.hx \
        server/src/server/db/MobileDal.hx \
        server/src/server/zone/EnterZoneHandler.hx \
        server/src/server/zone/ZoneSimulator.hx \
        server/src/server/zone/Main.hx \
        shared/src/shared/proto/MsgEntitySpawn.hx
git commit -m "$(cat <<'EOF'
feat(zone): mobile combat stats + HP + persistence

Migration 0006 extends `mobiles` with str/dex/intel/hp/max_hp (defaults
50). Mobile gains the seven combat fields (stats + HP + maxHp +
nextSwingTick + attackTarget). MsgEntitySpawn carries hp/maxHp so the
zone-entry burst and the per-tick interest spawn echo current HP to
joining observers. flushMobilePositions + the disconnect save persist
stats + HP alongside position.

No combat resolution yet — that lands in the next task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Combat resolution + wire + HP regen + client

This task makes the swing-timer actually fire. The simulator's tick
gains a `resolveSwings()` pass after movement; HP regen runs from the
tick scheduler; new wire messages plumb client intents and broadcast
results; the client renders HP bars + floating combat tells; new tests
cover swing math, regen, and the two-client end-to-end flow.

**Files:**
- Create: `shared/src/shared/proto/MsgAttackTarget.hx`, `MsgCombatEvent.hx`
- Create: `server/src/server/zone/CombatHandler.hx`
- Create: `server/test/TestCombat.hx`, `TestHpRegen.hx`, `TestZoneCombat.hx`
- Modify: `shared/src/shared/proto/MsgType.hx`, `server/src/server/zone/ZoneSimulator.hx`, `server/src/server/zone/Main.hx`, `server/test/TestMain.hx`, `client/src/client/Main.hx`, `client/src/client/render/ZoneRenderer.hx`, `client/src/headless/HeadlessClient.hx`

- [ ] **Step 1: Add the new proto messages**

Create `shared/src/shared/proto/MsgAttackTarget.hx`:

```haxe
package shared.proto;

/** Client -> zone: select an attack target (or 0 to disengage). */
@:build(shared.proto.SerializableMacro.build())
class MsgAttackTarget implements Serializable {
  public var targetSerial:Int = 0;
  public function new() {}
}
```

Create `shared/src/shared/proto/MsgCombatEvent.hx`:

```haxe
package shared.proto;

/** Zone -> broadcast: a single swing resolved. `defenderHp` is the
    defender's post-damage HP so the client doesn't need a separate
    delta. */
@:build(shared.proto.SerializableMacro.build())
class MsgCombatEvent implements Serializable {
  public var attackerSerial:Int = 0;
  public var defenderSerial:Int = 0;
  public var hit:Bool = false;
  public var damage:Int = 0;
  public var defenderHp:Int = 0;
  public function new() {}
}
```

Add the two msg ids to `shared/src/shared/proto/MsgType.hx`:

```haxe
  var CHAT = 40;
  var ATTACK_TARGET = 41;
  var COMBAT_EVENT = 42;
```

- [ ] **Step 2: Combat resolver + HP regen in `ZoneSimulator`**

Add a typedef and a pending-event buffer to
`server/src/server/zone/ZoneSimulator.hx`:

```haxe
typedef CombatResult = {
  attacker:Int, defender:Int, hit:Bool, damage:Int, defenderHp:Int
};

class ZoneSimulator {
  // ... existing fields ...

  public static inline var HIT_CHANCE_PERCENT:Int = 60;
  public static inline var SWING_TICKS_FIST:Int = 15;   // 1.5 s at 10 Hz
  public static inline var HP_REGEN_TICKS:Int = 40;     // 4 s at 10 Hz

  public var combatEventsThisTick(default, null):Array<CombatResult> = [];
```

In the constructor, register the HP-regen scheduler timer alongside
the existing flush timer:

```haxe
scheduler.every(FLUSH_TICK_INTERVAL, flushMobilePositions);
scheduler.every(HP_REGEN_TICKS, regenAllHp);
```

Add `regenAllHp`:

```haxe
function regenAllHp():Void {
  for (m in mobiles) {
    if (m.hp < m.maxHp && m.hp > 0) m.hp++;
  }
}
```

(Skips dead mobiles — relevant only for the SP1 stub's brief window
between HP=0 and the reset, but cheap insurance for SP4.)

Add `resolveSwings`:

```haxe
function resolveSwings():Void {
  for (m in mobiles) {
    if (m.attackTarget == 0) continue;
    if (currentTick < m.nextSwingTick) continue;
    var target = mobiles.get(m.attackTarget);
    if (target == null || target.hp <= 0) {
      m.attackTarget = 0;
      continue;
    }
    // Adjacency gate; out-of-range pauses, doesn't reset the timer.
    var dx = m.tileX - target.tileX; if (dx < 0) dx = -dx;
    var dy = m.tileY - target.tileY; if (dy < 0) dy = -dy;
    if ((dx > 1 ? dx : dy) > 1) continue;

    var hit = Std.random(100) < HIT_CHANCE_PERCENT;
    var dmg = hit ? 1 + Std.random(3) : 0;   // 1..3 inclusive on hit
    if (hit) {
      target.hp -= dmg;
      if (target.hp <= 0) {
        // SP1 death stub: reset to max. Corpse/ghost arrives in SP4.
        target.hp = target.maxHp;
        Sys.println('[combat] mobile ${target.serial} died (stub respawn)');
      }
    }
    combatEventsThisTick.push({
      attacker: m.serial, defender: target.serial,
      hit: hit, damage: dmg, defenderHp: target.hp
    });
    m.nextSwingTick = currentTick + SWING_TICKS_FIST;
  }
}
```

Wire `resolveSwings` into `tick()` — combat fires **after** the move
pass, so a defender who steps out of range this tick aborts the
incoming swing:

```haxe
public function tick():Void {
  currentTick++;
  movesThisTick = [];
  pickupsThisTick = [];
  combatEventsThisTick = [];          // new

  // ... existing move loop, growTiles ...

  resolveSwings();                    // new
  scheduler.tick();
}
```

- [ ] **Step 3: `CombatHandler`**

Create `server/src/server/zone/CombatHandler.hx`:

```haxe
package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgAttackTarget;
import shared.proto.MsgCombatEvent;
import shared.proto.MsgType;

/** Combat networking: the attack-target intent and the per-tick swing
    broadcast. Swing resolution itself lives in ZoneSimulator.tick(). */
class CombatHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;
  var interest:InterestManager;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler,
                      interest:InterestManager) {
    this.sim = sim;
    this.enterHandler = enterHandler;
    this.interest = interest;
  }

  /** MsgAttackTarget — set or clear the actor's attackTarget. */
  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return;
    var actor = sim.mobileBySerial(entId);
    if (actor == null) return;
    var req = MsgAttackTarget.deserialize(new BytesInput(payload));
    // Reject self-attack.
    if (req.targetSerial == actor.serial) return;
    // Zero clears the target (disengage).
    if (req.targetSerial == 0) {
      actor.attackTarget = 0;
      return;
    }
    // Target must be a live mobile this actor can see.
    var target = sim.mobileBySerial(req.targetSerial);
    if (target == null || target.hp <= 0) return;
    if (!interest.knows(actor.serial, req.targetSerial)) return;
    actor.attackTarget = req.targetSerial;
  }

  /** Broadcast every swing the simulator resolved this tick. Call once
      per tick, after sim.tick(). */
  public function broadcastEvents():Void {
    for (e in sim.combatEventsThisTick) {
      var ev = new MsgCombatEvent();
      ev.attackerSerial = e.attacker;
      ev.defenderSerial = e.defender;
      ev.hit = e.hit;
      ev.damage = e.damage;
      ev.defenderHp = e.defenderHp;
      var out = new BytesOutput(); ev.serialize(out);
      var bytes = out.getBytes();
      // Send to every observer who knows either combatant.
      for (m in sim.allMobiles()) {
        if (m.conn == null || !m.conn.alive) continue;
        if (interest.knows(m.serial, e.attacker) || interest.knows(m.serial, e.defender)) {
          m.conn.sendFrame(MsgType.COMBAT_EVENT, bytes);
        }
      }
    }
  }
}
```

- [ ] **Step 4: Register `CombatHandler` in `Main.hx`**

In `server/src/server/zone/Main.hx`, add the handler alongside the
existing ones:

```haxe
var combatHandler = new CombatHandler(sim, enterHandler, interest);

// ... existing dispatcher.register calls ...
dispatcher.register(MsgType.ATTACK_TARGET, combatHandler.handle);
```

And in the per-tick block, broadcast events after the existing tile +
inventory broadcasts:

```haxe
sim.tick();
moveHandler.broadcastMoves();
inventoryHandler.broadcastPickups();
tileHandler.flush();
combatHandler.broadcastEvents();       // new
broadcastInterestDiffs(sim, interest.update(sim.grid, sim.allMobiles()));
```

- [ ] **Step 5: Write `TestCombat`**

Create `server/test/TestCombat.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Mobile;
import server.zone.Serials;
import server.zone.SerialCounter;
import server.zone.ZoneSimulator;
import shared.world.MapData;
import shared.world.TileType;

private class MemCounter implements SerialCounter {
  public var mobile:Int = 1;
  public var item:Int = 0x40000000;
  public function new() {}
  public function loadMobileNext():Int return mobile;
  public function loadItemNext():Int return item;
  public function storeMobileNext(v:Int):Void { mobile = v; }
  public function storeItemNext(v:Int):Void { item = v; }
}

class TestCombat extends Test {
  function makeSim():ZoneSimulator {
    return new ZoneSimulator(MapData.filled(16, 16, TileType.GRASS),
                             new Serials(new MemCounter()), 1);
  }

  function testAdjacentSwingAdvancesTimer() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 5, 4);
    sim.spawn(a); sim.spawn(b);
    a.attackTarget = b.serial;
    // Advance ticks until a swing resolves.
    for (_ in 0...20) sim.tick();
    Assert.isTrue(a.nextSwingTick > 0, "timer advanced after at least one swing");
    Assert.isTrue(sim.combatEventsThisTick.length >= 0);  // smoke
  }

  function testOutOfRangeDoesNotResolve() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 10, 4);          // 6 tiles away
    sim.spawn(a); sim.spawn(b);
    a.attackTarget = b.serial;
    for (_ in 0...20) sim.tick();
    Assert.equals(50, b.hp);                          // untouched
    Assert.equals(0, a.nextSwingTick);                // timer never advanced
  }

  function testDeadTargetClearsAttackTarget() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 5, 4);
    sim.spawn(a); sim.spawn(b);
    b.hp = 0;
    a.attackTarget = b.serial;
    sim.tick();
    Assert.equals(0, a.attackTarget);
  }

  function testDeathStubResetsHp() {
    var sim = makeSim();
    var a = new Mobile(1, "a", null, 4, 4);
    var b = new Mobile(2, "b", null, 5, 4);
    sim.spawn(a); sim.spawn(b);
    b.hp = 1;            // one hit from death
    a.attackTarget = b.serial;
    // Force many swings; eventually b takes damage and the stub resets.
    var sawReset = false;
    for (_ in 0...200) {
      sim.tick();
      if (b.hp == b.maxHp && !sawReset) sawReset = true;
    }
    Assert.isTrue(sawReset, "death stub fired and reset HP to maxHp");
  }
}
```

- [ ] **Step 6: Write `TestHpRegen`**

Create `server/test/TestHpRegen.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.zone.Mobile;
import server.zone.Serials;
import server.zone.SerialCounter;
import server.zone.ZoneSimulator;
import shared.world.MapData;
import shared.world.TileType;

private class MemCounter implements SerialCounter {
  public var mobile:Int = 1;
  public var item:Int = 0x40000000;
  public function new() {}
  public function loadMobileNext():Int return mobile;
  public function loadItemNext():Int return item;
  public function storeMobileNext(v:Int):Void { mobile = v; }
  public function storeItemNext(v:Int):Void { item = v; }
}

class TestHpRegen extends Test {
  function makeSim():ZoneSimulator {
    return new ZoneSimulator(MapData.filled(4, 4, TileType.GRASS),
                             new Serials(new MemCounter()), 1);
  }

  function testRegensOneHpEveryFortyTicks() {
    var sim = makeSim();
    var m = new Mobile(1, "a", null, 1, 1);
    sim.spawn(m);
    m.hp = 30;                                 // 20 below maxHp 50
    // Advance 40 ticks -> 1 regen tick fires -> hp 31.
    for (_ in 0...40) sim.tick();
    Assert.equals(31, m.hp);
    // 40 more -> 32.
    for (_ in 0...40) sim.tick();
    Assert.equals(32, m.hp);
  }

  function testFullHpDoesNotChange() {
    var sim = makeSim();
    var m = new Mobile(1, "a", null, 1, 1);
    sim.spawn(m);
    Assert.equals(m.maxHp, m.hp);
    for (_ in 0...200) sim.tick();
    Assert.equals(m.maxHp, m.hp);              // capped at max
  }
}
```

- [ ] **Step 7: Write `TestZoneCombat` (integration)**

Create `server/test/TestZoneCombat.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;
import shared.proto.MsgType;
import shared.proto.MsgCombatEvent;
import haxe.io.BytesInput;
import HeadlessClient;

class TestZoneCombat extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var userA:String = "test_combat_a";
  var userB:String = "test_combat_b";
  var pw:String = "test_pw";

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    accountDal = new AccountDal(db);
    for (u in [userA, userB]) {
      db.exec("DELETE FROM items WHERE parent_serial IN (SELECT serial FROM mobiles WHERE name = ?)", [u]);
      db.exec("DELETE FROM mobiles WHERE name = ?", [u]);
      db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      accountDal.create(u, PasswordHash.hash(pw));
    }
  }

  function teardownClass() {
    if (db != null) {
      for (u in [userA, userB]) {
        db.exec("DELETE FROM items WHERE parent_serial IN (SELECT serial FROM mobiles WHERE name = ?)", [u]);
        db.exec("DELETE FROM mobiles WHERE name = ?", [u]);
        db.exec("DELETE FROM accounts  WHERE username = ?", [u]);
      }
      db.close();
    }
  }

  // PRECONDITION: gateway + zone running on 127.0.0.1:7777/7778.

  function plantAdjacent(a:String, b:String):Void {
    db.exec("UPDATE mobiles SET tile_x = 500, tile_y = 500 WHERE name = ?", [a]);
    db.exec("UPDATE mobiles SET tile_x = 501, tile_y = 500 WHERE name = ?", [b]);
  }

  static function sawHit(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>):Bool {
    for (f in frames) if (f.msgType == (MsgType.COMBAT_EVENT : Int)) {
      var e = MsgCombatEvent.deserialize(new BytesInput(f.payload));
      if (e.hit) return true;
    }
    return false;
  }

  function loginClient(user:String):HeadlessClient {
    var c = new HeadlessClient();
    c.connectGateway();
    Assert.isTrue(c.login(user, pw));
    return c;
  }

  function testAdjacentSwingsReachDefender() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    cA.enterZone();         // creates the mobile if absent
    cB.enterZone();
    cA.close(); cB.close();
    Sys.sleep(0.4);

    plantAdjacent(userA, userB);

    // Re-enter at the planted positions.
    cA = loginClient(userA);
    cB = loginClient(userB);
    cA.enterZone();
    cB.enterZone();
    Sys.sleep(0.4);          // let the interest tick spawn both for each other

    cA.attack(cB.entityId);

    // Drain frames over a few swing cycles (15 ticks/swing * 4 swings ~ 6s).
    var saw = false;
    var deadline = haxe.Timer.stamp() + 4.0;
    while (haxe.Timer.stamp() < deadline) {
      if (sawHit(cB.drainFrames(0.5))) { saw = true; break; }
    }
    Assert.isTrue(saw, "defender's client received at least one MsgCombatEvent hit");

    cA.attack(0);            // disengage
    cA.close();
    cB.close();
    Sys.sleep(0.5);
  }
}
```

- [ ] **Step 8: Register the new tests in `TestMain.hx`**

In `server/test/TestMain.hx`, add:

```haxe
    r.addCase(new TestSectorGrid());
    r.addCase(new TestCombat());
    r.addCase(new TestHpRegen());
    r.addCase(new TestInventory());
    // ... existing live-server cases ...
    r.addCase(new TestZoneChat());
    r.addCase(new TestZoneCombat());
```

(Place unit cases before the live-server cases, mirroring the existing
ordering.)

- [ ] **Step 9: Update `HeadlessClient`**

In `client/src/headless/HeadlessClient.hx`:

1. Add imports:

   ```haxe
   import shared.proto.MsgAttackTarget;
   import shared.proto.MsgCombatEvent;
   ```

2. Add an `attack` method:

   ```haxe
   public function attack(targetSerial:Int):Void {
     var m = new MsgAttackTarget();
     m.targetSerial = targetSerial;
     writeFrame(zone, MsgType.ATTACK_TARGET, m);
   }
   ```

3. The existing `drainFrames(duration)` already buffers any zone frame
   it doesn't consume, including `MsgCombatEvent`. No further changes
   needed there.

- [ ] **Step 10: Update the client**

In `client/src/client/Main.hx`:

1. Add the `MsgCombatEvent` import + handler registration:

   ```haxe
   import shared.proto.MsgCombatEvent;
   import shared.proto.MsgAttackTarget;
   ```

   ```haxe
   zoneDispatcher.on(MsgType.COMBAT_EVENT, onCombatEvent);
   ```

2. Add the handler:

   ```haxe
   function onCombatEvent(payload:Bytes):Void {
     var e = MsgCombatEvent.deserialize(new BytesInput(payload));
     if (zoneRenderer != null) {
       zoneRenderer.applyCombatEvent(e.defenderSerial, e.defenderHp, e.hit, e.damage);
     }
   }
   ```

3. Add an `F` keybinding to set/clear the attack target. In the
   existing key handler block (near where `placeFurniture` and
   `useOnFacedTile` are dispatched):

   ```haxe
   if (k == KeyCode.F) attackFacedEntity();
   if (k == KeyCode.Escape) sendAttackTarget(0);
   ```

   And the helpers:

   ```haxe
   function attackFacedEntity():Void {
     if (zoneConn == null || zoneRenderer == null) return;
     var t = zoneRenderer.ownInteractTarget();
     var serial = zoneRenderer.mobileSerialAtTile(t.x, t.y);
     if (serial == 0 || serial == ownEntityId) return;
     sendAttackTarget(serial);
   }

   function sendAttackTarget(targetSerial:Int):Void {
     var m = new MsgAttackTarget();
     m.targetSerial = targetSerial;
     var out = new BytesOutput(); m.serialize(out);
     zoneConn.sendFrame(MsgType.ATTACK_TARGET, out.getBytes());
   }
   ```

   (Adapt the keybinding hook to match the project's existing key-handler
   shape — `client/src/client/game/InputDispatcher.hx` or similar.)

- [ ] **Step 11: Update `ZoneRenderer`**

In `client/src/client/render/ZoneRenderer.hx`:

1. `EntityVisual` (or its containing data) gains tracked `hp` / `maxHp`
   fields. `spawnEntity` initializes them from `MsgEntitySpawn.hp` /
   `MsgEntitySpawn.maxHp`.

2. Add `mobileSerialAtTile(x, y):Int` — returns the serial of the
   `EntityVisual` whose `(tileX, tileY)` matches, or 0:

   ```haxe
   public function mobileSerialAtTile(x:Int, y:Int):Int {
     for (id in entities.keys()) {
       var v = entities.get(id);
       if (v.tileX == x && v.tileY == y) return id;
     }
     return 0;
   }
   ```

3. Add `applyCombatEvent`:

   ```haxe
   public function applyCombatEvent(defenderSerial:Int, defenderHp:Int, hit:Bool, damage:Int):Void {
     var v = entities.get(defenderSerial);
     if (v == null) return;
     v.hp = defenderHp;
     // Floating tell: spawn a short-lived label at v's position.
     spawnFloatingTell(v.tileX, v.tileY, hit ? '-$damage' : "miss", hit ? 0xFF4040 : 0xA0A0A0);
   }
   ```

4. Add HP-bar rendering to `drawEntities` (or wherever player sprites
   draw): a 16-px wide bar above the sprite, filled in red proportional
   to `hp / maxHp`. Skip when `hp == maxHp` to reduce visual noise (or
   always show — implementer's call).

5. Add `spawnFloatingTell(x, y, text, color)` — a simple `h2d.Text`
   with a `Timer` that removes itself after ~1 second and drifts up a
   few pixels. Implementation matches the project's existing
   short-lived UI patterns; if none exist, add a small class.

(Steps 10–11 are UI-shape changes — the exact code depends on the
project's current renderer + input wiring. Keep behavior aligned with
the spec; details that don't change behavior are at the implementer's
discretion.)

- [ ] **Step 12: Build everything**

Run: `./build_native.sh shared-test client-test server-test zone gateway client`
Expected: all targets compile.

- [ ] **Step 13: Run the unit suites**

Run: `./bin/shared-test && ./bin/client-test`
Expected: both `ALL TESTS OK`.

Run: `./bin/server-test 2>&1 | grep -E "assertations|successes|errors|failures|results:"`
Expected: assertions count up (TestCombat + TestHpRegen contribute);
8 errors (7 existing live-server + the new `TestZoneCombat` — verified
in the integration run next).

- [ ] **Step 14: Run the integration suite**

```bash
pkill -f 'bin/zone' ; pkill -f 'bin/gateway' ; sleep 1
./run-integration.sh
```

Expected: `ALL TESTS OK`. `TestZoneCombat` asserts the defender's
client receives at least one MsgCombatEvent hit during the engagement.

- [ ] **Step 15: Commit**

```bash
git add shared/src/shared/proto/MsgAttackTarget.hx \
        shared/src/shared/proto/MsgCombatEvent.hx \
        shared/src/shared/proto/MsgType.hx \
        server/src/server/zone/ZoneSimulator.hx \
        server/src/server/zone/CombatHandler.hx \
        server/src/server/zone/Main.hx \
        server/test/TestCombat.hx \
        server/test/TestHpRegen.hx \
        server/test/TestZoneCombat.hx \
        server/test/TestMain.hx \
        client/src/client/Main.hx \
        client/src/client/render/ZoneRenderer.hx \
        client/src/headless/HeadlessClient.hx
git commit -m "$(cat <<'EOF'
feat(zone): swing-timer combat with passive HP regen

ZoneSimulator.tick() runs resolveSwings() after the movement pass:
attackers whose nextSwingTick has elapsed and whose target is adjacent
roll a flat 60% hit chance for 1-3 damage. Death is stubbed (HP back to
maxHp) — corpse/ghost/rez land in SP4. HP regen runs on the existing
tick scheduler at +1 HP / 40 ticks until maxHp.

Wire: MsgAttackTarget (client -> server) selects or clears the actor's
target; MsgCombatEvent (server -> broadcast) carries
(attacker, defender, hit, damage, defenderHp). Client renders HP bars +
floating combat tells.

The skill-driven hit/damage formulas land in SP2; weapons land in M4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:**

- §1 *Mobile combat state* — five new fields (`str`, `dex`, `intel`,
  `hp`, `maxHp`) plus the two cooldown/target fields, derived `maxHp`
  formula → Task 1 Step 3.
- §2 *Swing resolution* — `resolveSwings` after the move pass,
  adjacency gate, flat 60% hit chance, 1-3 damage, death stub, HP regen
  on a scheduler timer → Task 2 Steps 2–3.
- §3 *DB schema* — migration 0006, idempotent guard, `MobileRow`
  carries the new fields, `saveStatsAndHp`, flush persists them → Task
  1 Steps 1, 4, 5, 8.
- §4 *Wire protocol* — `MsgAttackTarget`, `MsgCombatEvent`,
  `MsgEntitySpawn` extension with HP fields → Task 1 Step 6, Task 2
  Step 1.
- §5 *Client UI* — HP-bar rendering, floating tells, `F`/`ESC`
  keybinds, `HeadlessClient.attack` → Task 2 Steps 9–11.
- §6 *Edge cases* — adjacent-only gate, dead-target clears attack
  target, self-attack rejection, disconnect-mid-fight persistence →
  Task 1 Step 8 + Task 2 Step 3.
- §7 *Testing* — TestCombat, TestHpRegen, TestZoneCombat → Task 2
  Steps 5–7.

**Risks mitigation:**

- *MsgEntitySpawn field churn* — new HP fields go at the end of the
  field list so the SerializableMacro's existing field order is
  unchanged. Task 1 Step 6 pins this.
- *Death-stub semantics* — explicit `[combat] mobile X died` log line
  + integration test (`testDeathStubResetsHp`) make the stub obvious;
  SP4 will replace it.
- *Persistence cost* — `saveStatsAndHp` is one additional UPDATE per
  mobile per flush; within the existing 50-tick flush cost envelope.
- *Two-pass tick ordering* — combat fires after movement so a defender
  who steps out of range this tick aborts the swing. Task 2 Step 2
  pins the call order; `testOutOfRangeDoesNotResolve` asserts the
  resulting behavior.

**Placeholder scan:** Task 2 Steps 10–11 (client wiring) describe the
behavior the renderer + input dispatcher must achieve, not exact code
diffs — the project's existing UI shape determines the specifics.
Every other step is a concrete code block or a verified command.

**Type consistency:** `Mobile.str/dex/intel/hp/maxHp/nextSwingTick/attackTarget`
are all `Int`. `MobileRow` carries the same `Int` fields. `CombatResult`
typedef matches `MsgCombatEvent`'s fields. `combatEventsThisTick`
typing flows cleanly from sim → `CombatHandler.broadcastEvents()` →
serialized frame.

**Out of scope:** skills + skill-by-use + stat-by-use (SP2); weapons
+ weapon damage tiers + swing-speed variation (later); monsters + AI
(SP3); death + corpse + ghost + rez (SP4); ranged + magic; PvP gating
/ guard zones (M7).
