# Interest Management (visible-range filtering) — Design

**Date:** 2026-05-17
**Status:** Approved (design); pending implementation plan

## Context

This is the first of three sub-projects that make up milestone **M2 — Multiple
players in one zone**. M2 decomposes into independent pieces, each with its own
spec → plan → implementation cycle:

1. **Interest management (visible-range filtering)** ← *this spec*
2. Chat + emotes
3. CI + headless bots

Today the zone broadcasts entity events to **everyone**: `EnterZoneHandler`
syncs every existing entity to a joiner and the joiner to every existing
client, and `MoveIntentHandler.broadcastMoves` sends every `EntityMove` to
every entity. This sub-project replaces that with per-observer visible-range
filtering — *interest management* — so a player only hears about entities near
them, with spawn/despawn firing as entities enter and leave each other's view.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| M2 structure | Three separate spec → plan → build cycles |
| First piece | Interest management |
| AOI shape & size | Square (Chebyshev), generous — ~64-tile-wide |
| AOI algorithm | Simple O(n²) recompute per tick, behind a clean interface |
| Boundary flicker | Hysteresis band (separate spawn/despawn extents) |
| Mid-move enter | Spawn at the entity's current tile (accept ≤1-tile snap) |

## Scope

**In scope:** a server-side `InterestManager`; wiring it into the zone tick
loop, `EnterZoneHandler`, `MoveIntentHandler.broadcastMoves`, and the
disconnect path.

**Out of scope:** chat, emotes, CI, bots (later M2 sub-projects); spatial-grid
optimization (the O(n²) recompute is behind an interface so a grid can replace
it later without touching callers); any client change; any wire-protocol
change (existing `EntitySpawn`/`EntityMove`/`EntityDespawn` are reused as-is).

## Section 1 — The `InterestManager`

A new module `server/src/server/zone/InterestManager.hx`. It is **pure** — no
sockets, no I/O — so it is unit-testable in isolation.

**State:**

- `known:Map<Int, Map<Int,Bool>>` — for each observer entity ID, the set of
  entity IDs that observer currently knows about (a `Map<Int,Bool>` used as a
  set).

**Constants:**

- `SPAWN_EXTENT = 32` — an entity enters an observer's known-set when their
  Chebyshev (square) tile distance is ≤ 32. This yields a ~64-tile-wide
  square area of interest, comfortably larger than the 40×30-tile client
  viewport so entities appear before reaching the screen edge.
- `DESPAWN_EXTENT = 34` — a known entity is dropped only when distance > 34.
  The 32–34 hysteresis band prevents spawn/despawn flicker when an entity
  walks the AOI boundary.

**Interface:**

- `update(entities:Array<Character>):Array<InterestDiff>` — recompute every
  observer's known-set (O(n²) over the entity list) and return one
  `InterestDiff` per observer that changed. `InterestDiff` is
  `{observerId:Int, entered:Array<Int>, left:Array<Int>}`. An observer always
  implicitly knows itself; self is never reported in `entered`/`left`.
- `knows(observerId:Int, entityId:Int):Bool` — true if the observer currently
  knows that entity (or is that entity). Used to filter move broadcasts.
- `forget(entityId:Int):Array<Int>` — remove the entity as an observer and
  from every other observer's known-set; return the list of observer IDs that
  had known it (so the caller can send them an `EntityDespawn`).

**Distance rule:** an entity transitions into the known-set at Chebyshev
distance ≤ `SPAWN_EXTENT`; once known, it stays until distance > `DESPAWN_EXTENT`.
`update` applies this hysteresis by consulting the previous known-set.

## Section 2 — Zone loop integration

**`EnterZoneHandler`** is simplified. It keeps the immediate **self-echo**
`EntitySpawn` so the joining client renders itself without waiting for a tick.
The loop that syncs every existing entity to the newcomer (and the newcomer to
every existing client) is **removed** — the next interest tick produces those
spawns naturally (~100 ms later, imperceptible).

**Per zone tick**, in `server/src/server/zone/Main.hx`, after `sim.tick()` and
`moveHandler.broadcastMoves()`:

1. Call `interest.update(allEntities)`.
2. For each returned `InterestDiff`, look up the observer's connection and:
   - for each ID in `entered` — send an `EntitySpawn` (entity name + current
     `tileX`/`tileY`);
   - for each ID in `left` — send an `EntityDespawn`.

**`MoveIntentHandler.broadcastMoves`** changes its inner send loop: an
`EntityMove` for a mover is sent to an observer only when
`interest.knows(observer.id, mover.id)` is true — instead of to every entity.
`broadcastMoves` is given the `InterestManager` reference (constructor
parameter).

**Disconnect path** (`Main.hx`, where a dead connection is reaped): replace the
"broadcast despawn to all remaining entities" loop with
`var observers = interest.forget(entityId);` then send an `EntityDespawn` for
that entity to each connection in `observers`.

**Ordering note:** `interest.update` must run after `sim.tick()` (positions are
current) and the move broadcast should consult the *pre-update* known-sets so a
mover that just left an observer's view still gets its final move; the plan
will sequence `broadcastMoves` before `interest.update` within the tick.

## Section 3 — Edge cases

- **Self visibility.** An observer always knows itself, so its own moves always
  echo and it never despawns itself. `update` never lists self in a diff,
  which also avoids a double-spawn against `EnterZoneHandler`'s self-echo.
- **Mid-move enter.** When B enters A's view, A receives an `EntitySpawn` at
  B's *current tile*. If B is mid-step the client may snap B by at most one
  tile — accepted; no extra in-flight-move message is sent.
- **Map edges.** An AOI extending past the map bounds is harmless — there are
  simply fewer entities in range.
- **Forget consistency.** `forget` clears the entity in both directions (as an
  observer and as a known entity) so no stale IDs linger after disconnect.

## Section 4 — Testing

**Unit tests** — `server/test/TestInterestManager.hx`, pure, no sockets:

- two entities beyond `SPAWN_EXTENT` apart → neither is in the other's
  known-set; `knows()` returns false both ways;
- move one to within `SPAWN_EXTENT` → next `update` returns a diff with the
  other in `entered`;
- move it back out past `DESPAWN_EXTENT` → a diff with the other in `left`;
- move it into the 32–34 hysteresis band after being known → no `left` (still
  known); approaching from outside while in the band → not yet `entered`;
- `forget(id)` returns exactly the observers that knew the entity and leaves no
  stale references.

**Integration test** — extend the zone test suite: two `HeadlessClient`s enter
the zone far apart on the 1024×1024 map; assert neither receives the other's
`EntityMove`; walk one toward the other and assert an `EntitySpawn` arrives as
it crosses `SPAWN_EXTENT`.

**Regression:** the existing `TestZoneLifecycle` (single client) must still
pass — a lone client always knows itself, so its walk/persist flow is
unaffected.

## Risks

- **Tick ordering.** Move broadcast vs. interest update must be ordered so a
  just-departed mover still gets its final move and a just-arrived entity is
  spawned before its first move reaches the observer. The plan pins the order
  explicitly (broadcast moves, then update interest).
- **O(n²) recompute.** Fine for M2 player counts; the `InterestManager`
  interface is the seam where a spatial grid drops in later with no caller
  changes.

## Sub-project boundary

This sub-project is complete when entity spawn/move/despawn is filtered to each
observer's ~64-tile AOI with hysteresis, the `InterestManager` is unit-tested,
an integration test proves out-of-range entities are not broadcast, and the
existing zone tests still pass. Chat, emotes, and CI/bots follow as the
remaining M2 sub-projects.
