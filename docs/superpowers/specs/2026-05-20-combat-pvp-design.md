# Stats + HP + Swing-Timer Combat (PvP) — Design

**Date:** 2026-05-20
**Status:** Approved (design); pending implementation plan

## Context

M3 ("Combat + skills + death") first sub-project. The master design lays
out M3 as four interlocking systems — swing-timer combat, skills with
skill-by-use gain, monster spawner + AI, and death/corpse/ghost/rez.
This SP carves off the smallest sliver that demos something playable:
two clients can attack each other; HP exists; when HP hits 0 the loser
gets a respawn-stub. Everything else lands in subsequent SPs.

The supporting infrastructure from the UO-patterns arc is now in place:

- The **tick scheduler** drives passive HP regen.
- The unified **`Mobile`** carries the new combat state (`hp`, `maxHp`,
  `nextSwingTick`, `attackTarget`) and gives NPCs (SP3) the same data
  model players use here.
- The **sector grid** makes the adjacency check (`entityAt(x, y)`) O(1).
- **Persistent serials** let `MsgCombatEvent` reference combatants by id.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Stat-gain in SP1 | No — STR/DEX/INT are static; gain-by-use lands in SP2 alongside skills |
| HP regen | Yes — passive `+1 HP` every 40 ticks (4 seconds at 10 Hz) until full |
| Combat event wire | One `MsgCombatEvent` per swing carrying `(attacker, defender, hit, damage)` |
| Death in SP1 | Stub — HP=0 resets HP to `maxHp` and broadcasts; corpse/ghost/rez in SP4 |
| Hit chance in SP1 | Flat 60% — skill-driven formula lands in SP2 |
| Damage in SP1 | Random 1-3 bare-fist; weapon scaling later |
| Range gate | Chebyshev ≤ 1 (adjacent only); out-of-range pauses the swing without consuming the timer |

**Why HP regen on a scheduler timer** rather than per-tick? Per-tick regen
would advance HP every 100 ms — visually noisy on the wire and obscures
"combat" vs. "between fights" rhythm. A scheduler timer running every
40 ticks (4 s) gives clear pacing and exercises the tick-scheduler
patterns introduced in arc 1.

**Why a flat 60% hit chance for SP1** instead of stats-only? The master
design's hit formula is `attackerWeaponSkill vs defenderWeaponSkill (or
Wrestling)` — neither skill nor weapon is in scope yet. Picking
stats-based hit-chance here would be a throwaway formula replaced by SP2.
A flat 60% is honest about the placeholder and trivially testable.

## Scope

**In scope:** stat fields (`str`, `dex`, `intel`, `hp`, `maxHp`) on
`Mobile` and the `mobiles` DB schema; `nextSwingTick` cooldown gate;
`attackTarget` field; per-tick swing resolver in `ZoneSimulator`;
adjacency-only range; flat hit chance + random bare-fist damage;
passive HP regen via the tick scheduler; `MsgAttackTarget` (client →
server) and `MsgCombatEvent` (server → broadcast) wire messages;
HP-change broadcast; HP-0 stub that resets to `maxHp`.

**Out of scope:** skills, skill-by-use gain, stat-by-use gain (SP2);
weapons + weapon damage tiers + swing-speed variation (deferred —
fists for everyone in SP1); monsters + AI (SP3); death + corpse +
ghost + rez (SP4); ranged attacks; magic; PvP gating / guard zones (M7);
combat formulas beyond the placeholders; bandage Healing skill (M3 SP2+).

## Section 1 — `Mobile` combat state

`server/src/server/zone/Mobile.hx` gains five fields:

```haxe
public var str:Int = 50;
public var dex:Int = 50;
public var intel:Int = 50;   // `int` is a Haxe reserved word; use `intel`
public var hp:Int;
public var maxHp:Int;
public var nextSwingTick:Int = 0;
/** 0 = not attacking; otherwise the target's serial. */
public var attackTarget:Int = 0;
```

`maxHp` is derived from `str` at construction:
`maxHp = 25 + str / 2` → `50` at the default `str=50`. `hp` initializes
to `maxHp`. The formula is a placeholder — when SP2 adds stat-gain
mechanics, `recomputeMaxHp()` will be called on stat changes.

Stats are **starting values only** — no in-SP1 mechanism mutates them.
The DB schema (§3) stores them as plain columns.

## Section 2 — Swing resolution in `ZoneSimulator`

The simulator's per-tick loop gains a second pass after movement: for
each mobile that has an active `attackTarget` and whose `nextSwingTick`
has elapsed, resolve a swing.

```haxe
public function tick():Void {
  currentTick++;
  movesThisTick = [];
  pickupsThisTick = [];
  combatEventsThisTick = [];          // new

  // ... existing move loop, growTiles ...

  resolveSwings();                    // new — second pass
  scheduler.tick();
}
```

`resolveSwings`:

```haxe
function resolveSwings():Void {
  for (m in mobiles) {
    if (m.attackTarget == 0) continue;
    if (currentTick < m.nextSwingTick) continue;
    var target = mobiles.get(m.attackTarget);
    if (target == null || target.hp <= 0) {
      m.attackTarget = 0;             // clear stale target
      continue;
    }
    // Range gate: adjacent only. Out-of-range does NOT consume the
    // timer — the swing pauses and lands as soon as range closes.
    if (chebyshev(m, target) > 1) continue;

    var hit = Std.random(100) < HIT_CHANCE_PERCENT;
    var dmg = hit ? 1 + Std.random(3) : 0;   // 1..3 inclusive
    if (hit) {
      target.hp -= dmg;
      if (target.hp <= 0) {
        // Death stub: reset to maxHp; real death in SP4.
        target.hp = target.maxHp;
        Sys.println('[combat] mobile ${target.serial} died (stub respawn)');
      }
    }
    combatEventsThisTick.push({
      attacker: m.serial, defender: target.serial, hit: hit, damage: dmg, defenderHp: target.hp
    });
    m.nextSwingTick = currentTick + SWING_TICKS_FIST;
  }
}
```

Constants:

```haxe
public static inline var HIT_CHANCE_PERCENT:Int = 60;
public static inline var SWING_TICKS_FIST:Int = 15;   // 1.5 s at 10 Hz
public static inline var HP_REGEN_TICKS:Int = 40;     // 4 s
```

The `combatEventsThisTick` typedef:

```haxe
typedef CombatResult = {
  attacker:Int, defender:Int, hit:Bool, damage:Int, defenderHp:Int
};
```

A new `CombatHandler.broadcastCombatEvents()` (next section) drains it.

**HP regen** lives on the scheduler — registered in the constructor:

```haxe
scheduler.every(HP_REGEN_TICKS, regenAllHp);
```

```haxe
function regenAllHp():Void {
  for (m in mobiles) {
    if (m.hp < m.maxHp) m.hp++;
  }
}
```

Regen is uniform across all mobiles for SP1 (no stamina-or-combat gating).
The future hooks for "no regen while in combat" land in SP2 alongside
skills.

## Section 3 — DB schema

Migration `0006_combat_stats.sql` extends `mobiles`:

```sql
ALTER TABLE mobiles
  ADD COLUMN str    INT NOT NULL DEFAULT 50,
  ADD COLUMN dex    INT NOT NULL DEFAULT 50,
  ADD COLUMN intel  INT NOT NULL DEFAULT 50,
  ADD COLUMN hp     INT NOT NULL DEFAULT 50,
  ADD COLUMN max_hp INT NOT NULL DEFAULT 50;
```

`MobileDal` gains `saveStatsAndHp(serial, str, dex, intel, hp, maxHp)`
and `MobileRow` carries the five fields. The existing per-flush save
extends to also persist `hp` (so a player who logs out mid-combat
returns with their damaged HP intact); stats persist too (so SP2's
stat-gain has a place to land).

**Migration of existing rows:** the `DEFAULT 50` on each column gives
every pre-existing mobile a fresh `50/50/50/50/50` baseline. No data
loss; the column add is non-blocking under InnoDB.

## Section 4 — Wire protocol

Two new messages:

**`MsgAttackTarget`** (client → zone):

```haxe
@:build(shared.proto.SerializableMacro.build())
class MsgAttackTarget implements Serializable {
  public var targetSerial:Int = 0;   // 0 = stop attacking
  public function new() {}
}
```

`MsgType.ATTACK_TARGET = 41`. The server's `CombatHandler.handle` sets
`mobile.attackTarget = req.targetSerial` (or 0 to disengage). Validation:
target must be a live mobile serial within interest range.

**`MsgCombatEvent`** (zone → broadcast):

```haxe
@:build(shared.proto.SerializableMacro.build())
class MsgCombatEvent implements Serializable {
  public var attackerSerial:Int = 0;
  public var defenderSerial:Int = 0;
  public var hit:Bool = false;
  public var damage:Int = 0;
  public var defenderHp:Int = 0;    // post-damage HP so client doesn't need a separate delta
  public function new() {}
}
```

`MsgType.COMBAT_EVENT = 42`. Broadcast to every observer who knows
either combatant (via the InterestManager). The embedded `defenderHp`
lets the client render the new HP without a separate `MsgMobileHp`
message.

The `MsgEntitySpawn` body picks up the new HP/max-HP fields so a joining
client knows everyone's HP from the entry burst:

```haxe
class MsgEntitySpawn implements Serializable {
  public var entityId:Int = 0;
  public var name:String = "";
  public var itemTypeId:Int = 0;
  public var count:Int = 0;
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public var parentSerial:Int = 0;
  public var slot:Int = 0;
  public var hp:Int = 0;       // mobile only
  public var maxHp:Int = 0;    // mobile only
  public function new() {}
}
```

Items leave `hp`/`maxHp` at 0; mobiles fill them.

## Section 5 — Client UI

Two surface changes in `client/src/client/Main.hx`:

1. **Attack target selection.** A new keybinding — e.g., `F` — sends
   `MsgAttackTarget` for the mobile on the faced tile (via
   `ZoneRenderer.ownInteractTarget`). Pressing `F` again with no target
   in front, or `ESC`, sends `MsgAttackTarget(0)` to disengage.
2. **HP bar rendering.** `EntityVisual` gains an HP bar drawn above
   each mobile sprite. The bar reads `hp / maxHp` (from the renderer's
   tracked state, updated by `MsgEntitySpawn` and `MsgCombatEvent`).
   The local player's HP also renders in a corner of the screen with
   numbers (`HP 50 / 50`).

The renderer handles `MsgCombatEvent` by:
- Updating the defender's HP.
- Spawning an ephemeral floating-text tell at the defender's position:
  on hit, `-${damage}` in red; on miss, `miss` in grey. Fades over
  ~1 second. The tell is purely client-side, no extra state.

`HeadlessClient` adds:
- `attack(targetSerial:Int)` to send `MsgAttackTarget`.
- A `combatEvents:Array<{...}>` buffer drained from incoming
  `MsgCombatEvent` frames.

## Section 6 — Edge cases

- **Target leaves interest range.** `MsgCombatEvent` is only sent to
  observers in range. If the defender steps out of the attacker's
  interest, the attacker still resolves swings server-side; the
  defender just stops receiving the events. The attacker's client
  shows nothing until the defender re-enters AOI — acceptable for SP1.
- **Self-attack.** `MsgAttackTarget` with `targetSerial = self.serial`
  is rejected by `CombatHandler.handle`.
- **Attack target despawns** (logout mid-fight). The attacker's
  per-tick `mobiles.get(attackTarget)` returns null; `attackTarget`
  resets to 0. Next swing tick is a no-op.
- **HP=0 in the same tick as another swing landing.** The death-stub
  resets HP to `maxHp` immediately. The subsequent swing (from a
  different attacker in the same tick) sees a fresh-HP target and
  treats it normally. This is the SP1 stub; SP4 makes death a
  one-way state and these double-hit cases turn into a no-op on the
  dead target.
- **Disconnect mid-combat.** The existing
  `Main.hx` disconnect path saves position; it now also saves stats +
  HP via the extended `flushMobilePositions`. The attacker (if a
  different client) catches the despawn through the existing interest
  flow and stops swinging next tick.
- **Out-of-range while attacking.** As decided: the swing pauses, the
  timer doesn't advance. The attacker keeps `attackTarget` set; the
  moment range closes, the swing lands. The client UI shows the
  ongoing attack indicator without flicker.

## Section 7 — Testing

**Unit — `server/test/TestCombat.hx`** (new):

- A swing on an adjacent live target resolves: HP drops on hit, stays
  on miss; `nextSwingTick` advances by `SWING_TICKS_FIST`.
- A swing on a target two tiles away does *not* resolve — the timer
  stays at the un-elapsed value.
- A target with `hp=0` (just killed) clears the attacker's
  `attackTarget` next tick.
- Self-attack via `CombatHandler.handle` is rejected.
- The death stub fires when `hp <= 0` and resets to `maxHp`.

**Unit — `server/test/TestHpRegen.hx`** (new):

- A mobile at half HP regenerates exactly 1 HP per `HP_REGEN_TICKS`
  cycle, capped at `maxHp`.
- A mobile at full HP doesn't change.
- Regen is driven by the existing scheduler (assert by ticking the
  scheduler manually, not by waiting wall-clock).

**Integration — `TestZoneCombat.hx`** (new):

Boot two `HeadlessClient`s into the zone, position them adjacent via
the `UPDATE mobiles SET tile_x = ?, tile_y = ?` plant pattern from
`TestZoneInterest`, have one attack the other, drain `MsgCombatEvent`
frames, and assert:
- The defender's HP drops on observed hit events.
- After enough hits, the death stub fires (HP back to `maxHp`).
- After disengaging, the attacker stops emitting events.

**Regression:** the full unit + integration suite stays green —
existing `TestZoneInterest` / `TestZoneChat` / `TestZoneLifecycle`
should not require changes.

## Section 8 — Risks

- **MsgEntitySpawn field churn.** Adding `hp` / `maxHp` to the
  unified spawn message expands the on-wire payload by 8 bytes per
  spawned mobile. Negligible at SP1 scale; called out so the
  `SerializableMacro` field-order remains stable (new fields go at
  the end).
- **Death-stub semantics drift.** The "reset HP, log a message" stub
  is intentionally awkward — it should feel wrong, so it's obvious
  SP4 needs to land. The integration test asserts the stub fires;
  SP4 will replace it.
- **Hit-rate placeholder feels grindy at 60%.** Combat in SP1 isn't
  tuned — the goal is mechanics, not feel. SP2's skill-based hit
  formula will flatten this curve.
- **Persistence cost.** Adding `hp` to the 50-tick flush is one
  additional integer column update per mobile per flush. Within the
  existing `flushMobilePositions` cost envelope.
- **Two-pass tick ordering.** Combat resolution after movement
  matters: a defender who steps out of range *this tick* should
  cause the swing to abort, not land. The plan pins the ordering
  (move → combat → scheduler) and the unit test exercises the
  step-out case.

## Sub-project boundary

Complete when: `Mobile` carries the combat state; the migration extends
`mobiles` with the five new columns; the simulator resolves swings each
tick on the adjacency gate; `MsgAttackTarget` and `MsgCombatEvent` are
implemented end-to-end; passive HP regen runs from the tick scheduler;
the HP=0 stub fires and respawns the loser in place; client renders HP
bars + combat tells; the full unit + integration suite (including a new
two-client `TestZoneCombat`) is green.

This is the first of four M3 sub-projects. After it merges, SP2
(skills + skill-by-use gain + stat-by-use gain) layers onto the
swing-timer machinery established here.
