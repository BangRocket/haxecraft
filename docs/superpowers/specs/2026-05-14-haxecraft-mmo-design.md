# Haxecraft MMO — Design Spec

**Date:** 2026-05-14
**Status:** Design approved, pending implementation plan
**Lead:** Joshua
**Inspiration:** Ultima Online circa 1999

## Project Summary

A 2D top-down tile-based MMORPG inspired by Ultima Online (pre-Trammel, 1999 era). Built by evolving the existing `haxecraft` codebase (a Haxe/Heaps port of Notch's Minicraft) into a client/server architecture, then growing the design beyond Minicraft into a UO-flavored persistent shared world.

**Scope intent:** Indie ship. Eventually real players, indie timescale and budget acceptable (years to launch). Plan for migration paths; don't over-engineer.

**Scale target:** 100-500 concurrent players on launch (single shared world, multi-zone process), with the architectural ceiling extending to 1000+ via horizontal zone sharding.

**Team:** Joshua leading; implementation in collaboration with AI (effectively a solo-velocity project with AI-multiplier).

## Design Pillars

The "soul" of the game. From the UO pillars list, ranked by Joshua:

**Sacred / Core (in MVP):**

- Skill-based progression (no classes/levels; train-by-use; ~700 total skill cap)
- Real-time combat with weapon swing timers
- Reagent magic (spellbook + reagents consumed on cast)
- Death has weight (corpse drops with all gear, ghost form, resurrection ritual)
- Single persistent shared world (one shard architecturally; multiple zone processes internally)
- Full-loot PvP **outside guard zones**
- Guard zones (UO mechanic: NPC guards insta-kill aggressors inside town tile flags)
- Player-driven economy + crafting (NPC vendors also fine — player vendors deferred)
- Living-world content: hand-placed dungeons, monsters in zones, keyword-dialogue NPCs

**Later (post-MVP):**

- Player housing (placed in open world, persistent, decoration-driven)
- Reputation system (murder counts, blue/grey/red — eventually replaces simple guard-zone protection)
- Full quest infrastructure (UO 1999 had none either; defer indefinitely)

## Architecture — Approach 2: "Zone-sharded from day one"

A gateway process plus N zone processes, with one Postgres backing both. Designed to ship with a single zone in MVP and scale by adding zones, without re-architecting the simulation core.

```
                       ┌──────────────────┐
       Postgres ◄──────│  Gateway (1)     │
                       │  - auth          │
                       │  - char select   │
                       │  - routing       │
                       │  - zone registry │
                       │  - cross-zone    │
                       │    handoff       │
                       └────┬─────────────┘
                            │ control plane
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
      ┌──────────┐    ┌──────────┐    ┌──────────┐
      │ Zone A   │    │ Zone B   │    │ Zone C   │
      │ 10 Hz    │    │ 10 Hz    │    │ 10 Hz    │
      └────┬─────┘    └────┬─────┘    └────┬─────┘
           │ persist       │ persist       │ persist
           └───────────────┼───────────────┘
                           ▼
                       Postgres
                           ▲
                           │
                    ┌──────┴───────┐
                    │   Clients    │
                    └──────────────┘
```

### Process responsibilities

- **Gateway** (1 process). Auth, character creation and selection, zone registry (which zone owns which tile rect), brokering cross-zone player handoffs, central chat relay. Not in the gameplay hot path — once a client is in a zone, gateway only sees them again at zone transitions, global chat, or logout.
- **Zone server** (N processes; start with 1). Owns simulation for its tile rect. Authoritative on movement, combat, skills, items, NPCs, monsters within its rect. Ticks at 10 Hz. Talks directly to its clients. Writes mutations to Postgres with batching for hot state and synchronously for item/gold movement.
- **Postgres** (single instance for MVP). Characters, items, skills, world mutations, corpses, dropped items, NPC state. Sharded later when one box becomes the bottleneck.
- **Client** (Haxe/Heaps targeting HashLink initially, JS browser target deferred). Rendering, input, prediction, interpolation. Has no authoritative game state — purely a view + input device with prediction to hide latency.

### Why gateway + zones (not just zones)

Without a gateway, every client would need every zone's address and would re-auth on each crossing. Gateway gives us: one stable endpoint, central auth + anti-cheat + ban hammer, place for global chat without going through Postgres, and the coordinator for handoff (so a player is never in two zones or zero zones at once).

### MVP process layout

Two processes from day one: one gateway, one zone. Same binary capable of either role, started with a different flag. This validates the IPC boundary immediately rather than papering over it and rewriting later.

## Network Protocol

### Transport

TCP with length-prefixed binary frames. UDP wins only for sub-50ms shooters; TCP head-of-line blocking is fine for 10 Hz tile-step gameplay. WebSocket adapter possible later for browser client (same frame format wrapped in WS messages).

### Frame format

```
[u16 length][u8 msgType][payload bytes]
```

Hard cap 64 KB per frame.

### Message catalog

Defined as Haxe classes in `shared/proto/`, compiled into both client and server. Each message is decorated `@:serializable`. A build macro reads class fields and generates `read(input)` and `write(output)` methods at compile time. Zero runtime reflection, identical bytes on both sides. Adding or removing a field breaks both binaries until updated → no silent drift.

### Connection flow

1. Client connects to **Gateway** over TLS. Sends `Hello(protocolVersion, buildHash)`.
2. Login: `Login(user, pass)` → `LoginAck(sessionToken, characterList)`.
3. Char select: `EnterWorld(charId)` → Gateway loads character position, looks up owning zone, returns `ZoneHandoff(zoneHost, zonePort, handoffToken)` (gateway-signed, short TTL).
4. Client opens TCP connection to that zone, sends `EnterZone(handoffToken)`. Zone validates signature, loads character from DB, sends initial snapshot of visible tile rect and entities.
5. Gameplay proceeds zone-direct. Gateway connection stays open for global chat and admin commands.

### Zone-to-zone transition (the hard part)

1. Player walks onto boundary tile.
2. Old zone freezes that player (no further input accepted), pushes full state to gateway.
3. Gateway forwards to new zone, awaits `Ready` ack.
4. Gateway sends `ZoneHandoff` to client.
5. Client opens new connection to new zone, hands over `handoffToken`.
6. Old zone drops player from sim only **after** new zone confirms entry.

Invariant: never in two zones simultaneously; never in zero zones. The freeze-old-before-drop ordering is critical and a classic source of dupe bugs.

### Anti-cheat by construction

Client sends *intents* only — "move N", "swing at entity #42", "cast fireball at tile X,Y" — never authoritative state. Server validates and broadcasts. Speed hacks impossible by construction (server applies movement at server tick). Aimbot moot (tile-based). Packet replay needs nonces; deferred past week 1.

### Encryption

TLS for gateway from day one (credentials must be encrypted). Game-zone traffic plaintext for MVP; TLS-wrap before public launch. (UO ran unencrypted for years — we'll do better than that bar.)

### Bandwidth budget

~5-15 KB/s per active client × 200 in a zone = 2-3 MB/s per zone process. Comfortable on one box.

### Versioning

Protocol version int in `shared/constants.hx` plus build hash baked at compile time. Mismatched version returns explicit "client out of date" message; no silent failures. Dev builds tolerate mismatch with a warning flag.

## World Structure

### Coordinate system

Global integer tile coordinates, `(i32 x, i32 y)`. Zones own rectangular tile ranges. World origin = (0, 0). Tile size: **8×8 pixels** (matching haxecraft and Minifantasy native resolution).

### MVP world size

**One zone, 1024×1024 tiles** (≈6 screens wide at 1280-px viewport). Hand-authored. Contents:

- One starter town (~80×80 tile area) with `GUARD_ZONE` tile flag — site of NPC vendors, banker, healer/resurrector NPC.
- Open countryside (grass, forest, beach, river).
- Two hand-placed dungeon entrances leading to small dungeon maps (each ≈64×64).
- Spawn points for monsters in non-town areas.
- Resource nodes (trees, ore veins, fishing spots).

That is the entire shipping world for MVP. Small but coherent. Adding zones post-launch is *content* work, not *engineering* work — the system already supports it from day one.

### Tile data

```haxe
typedef Tile = {
  terrain : TileId,      // u16 — grass, sand, stone, water, etc.
  flags   : TileFlags,   // u16 bitfield — GUARD_ZONE, BLOCKING, NO_PVP
  overlay : OverlayId    // u16 — 0=none, else a static decoration ID
}
```

6 bytes/tile × 1024² = 6 MB per zone. Loaded once at zone process startup, kept in memory, never written back (terrain is immutable from gameplay).

### Dynamic world state

Lives in DB, cached in zone memory. Distinct from static terrain.

- `dropped_items` — item entity at (x, y, zone), decay timer
- `corpses` — corpse entity, contents, decay timer, owner-only window
- `resource_nodes` — chopped trees, depleted ore veins, with respawn timer
- `npc_spawns` — NPC current HP, position, respawn timer
- `houses` (later) — placed structures
- `mob_spawners` — definitions for monster spawn behavior in a region

Loaded by zone at startup. Persisted on change with batching (debounced ~5s) for most fields; synchronously for item/gold movement.

### Static terrain ≠ destructible

You do not mine the ground or chop arbitrary forest squares. Chopping a tree consumes a *resource node entity* placed on the terrain. The terrain underneath is permanent. Same model UO used. Keeps server load light and map data static. Housing will eventually punch overlay objects onto terrain, but houses are bounded entities, not free-form edits.

### Map authoring

**Tiled** (mapeditor.org). Layers map cleanly to terrain/flags/overlay/spawns. Custom tile properties for flags. Object layers for NPC spawn points, mob spawners, dungeon entrances. Tile size set to 8×8 in the editor.

Starting workflow: run haxecraft's existing worldgen to produce a *base layer*, then hand-edit in Tiled to carve out the town, dungeons, and notable terrain features.

### Inheriting from haxecraft

The existing `Tile` class hierarchy and tile-rendering pipeline mostly transfer. What changes: tiles become *pure data* server-side (no per-instance behavior) — behavior moves to entity systems (resource nodes, mob spawners). The client keeps tile rendering as-is.

## Movement Model

**Tile-step authority, smooth-interp rendering.** Server thinks in tiles only; all game logic (range, AoE, guard zone, line-of-sight) is tile-based. Client renders smooth pixel-interpolation between authoritative tile positions. This is what UO did. The 8×8 tile size makes step granularity small enough that motion looks fluid.

Step rate: ~4 tiles/sec walking, ~8 tiles/sec running (UO-classic). Stamina drained by running.

## Game Systems

### Stats

Three stats: **STR**, **DEX**, **INT**. Total stat cap 225 (allocate growth via use). HP function of STR, stamina function of DEX, mana function of INT.

### Skill system

MVP skill set (11 skills):

| Category | Skills |
|---|---|
| Melee | Swordsmanship, Wrestling (fallback / brawler) |
| Combat support | Tactics (damage bonus), Anatomy (damage bonus + Healing accuracy) |
| Magic | Magery, Evaluating Intelligence (spell damage) |
| Gathering | Mining, Lumberjacking |
| Crafting | Blacksmithy, Carpentry |
| Survival | Healing (bandages) |

Each skill: 0.0 to 100.0, stored as u16 = `skill × 10`. Use-based gain with diminishing return — high chance at low skill, near-zero at GM. Total skill cap **700**. Specialization matters.

Post-MVP skills (Fencing, Mace Fighting, Archery, Tinkering, Tailoring, Alchemy, Fishing, Stealing, Hiding, Stealth, Meditation, Resisting Spells, Cooking, Camping) slot into the same framework — they are content, not engineering.

### Combat

10 Hz tick drives everything. Each weapon has a **swing speed** in ticks (longsword=25 ticks=2.5s; dagger=15=1.5s). Each combatant has a `nextSwingTick` counter.

On swing tick:

1. **Hit chance** = `attackerWeaponSkill` vs `defenderWeaponSkill` (or Wrestling) — UO formula, ~50% at parity.
2. On hit: `damage = weapon.baseDamage × (1 + Tactics/100 × 0.625) × (1 + Anatomy/100 × 0.3)`
3. Armor reduces damage by AR%. No damage types in MVP (post-MVP: physical/fire/cold/poison/energy).
4. Skill gain check (combat skill + Tactics + Anatomy).
5. Reset `nextSwingTick`.

Combat is "attack this entity" then auto-swings until target dead, out of range, or attacker stops. No tab-target feel.

### Magic (Magery)

Reagent system: each spell consumes specific reagents from inventory + mana on cast. Casting: select spell from spellbook UI → click target → cast-time delay (1.5-3s by circle) → consume reagents + mana → effect resolves server-side. Movement interrupts casting.

MVP spellbook (15 spells):

| Circle | Spells |
|---|---|
| 1 | Heal, Magic Arrow, Reactive Armor |
| 2 | Cure, Harm |
| 3 | Fireball, Wall of Stone |
| 4 | Greater Heal, Lightning |
| 5 | Magic Reflection, Recall |
| 6 | Energy Bolt, Mark |
| 7 | Resurrection, Explosion |

Recall + Mark are UO's iconic travel system: mark a rune at a location, recall to it from anywhere.

### Death & ghost

1. HP → 0: player drops corpse at location containing **all gear + all inventory**. Player becomes ghost.
2. Ghost: greyscale render, can't interact with world, can't speak (only other ghosts hear you — spirit-speak gating is post-MVP).
3. Resurrection options: walk to NPC **healer** in town (always available), or another player casts Resurrection on you (Magery 60+).
4. Resurrected player has 1 HP, naked. Must return to corpse to loot back.
5. Corpse decays in **15 minutes**. Outside guard zones, anyone can loot. Inside guard zones, corpse is owner-only for first 5 minutes.

### Economy & crafting

- **NPC vendors:** fixed-price buy/sell. Stock includes basic gear (mediocre stats), reagents, bandages, food, tools (pickaxe, hatchet, hammer, saw).
- **Gold sinks:** repair from NPC blacksmith, reagent purchase, resurrection fee (small).
- **Gold sources:** mob loot, NPC buying junk loot (at half price).
- **Crafted gear > NPC gear:** crafted weapons/armor get quality tiers (ruin/standard/exceptional based on skill roll). Exceptional has bonus damage/AR. Drives demand for player crafters.
- **No player vendors in MVP.** Direct trade only (`/trade` UI, 2-phase, dupe-safe).
- **Banking:** every NPC banker has access to your bank box (256 items, weight-limited). Items in bank are safe.

### Guard zones

Implementation: `GUARD_ZONE` tile flag. When a player performs an aggressive action (melee swing on another player, harmful spell targeting another player, theft attempt) on a tile flagged `GUARD_ZONE`:

1. Server spawns a **Guard NPC** at aggressor's position next tick.
2. Guard one-shots aggressor (full HP nuke). Aggressor dies, drops corpse, becomes ghost.
3. Guard despawns 1 second later.

UO mechanic, mostly verbatim. Consensual duels in guard zones (`/duel` flag): post-MVP.

### Not in MVP

Calling out explicitly to prevent scope drift: no poison, no damage types, no mounts, no taming, no Necromancy/Chivalry/Bushido (any post-Renaissance UO mechanic), no factions, no PvP arenas, no player housing, no boats, no dyes, no stable masters, no commodity deeds, no item insurance.

## Persistence Model

### Database

PostgreSQL. Single instance for MVP. SQLite would work for sub-100 CCU but Postgres gives us real concurrency, replication paths, and the JSONB columns we lean on for item properties.

### Schema sketch

```sql
accounts(id, email, password_hash, created_at, last_login, banned_until)
characters(id, account_id, name UNIQUE, zone_id, tile_x, tile_y,
           str, dex, int, hp, mana, stamina, gold, is_ghost,
           created_at, last_save, locked_by_zone)
character_skills(character_id, skill_id, value)  -- value = u16, skill×10
character_inventory(character_id, container, slot, item_blob JSONB)
   -- container ∈ {backpack, equipment, bank}
world_items(zone_id, tile_x, tile_y, item_blob JSONB, decay_at)
world_corpses(zone_id, tile_x, tile_y, owner_char_id, contents JSONB,
              decay_at, owner_only_until)
world_resource_nodes(zone_id, tile_x, tile_y, type, state, respawn_at)
world_npc_state(zone_id, npc_id, hp, vendor_stock JSONB, respawn_at)
```

**Why JSONB for item_blob:** items have arbitrary properties (durability, quality tier, who crafted it, magical bonuses later). Modeling each as a column = schema bloat. JSONB lets us evolve properties without migrations; specific keys can be indexed when needed.

**Why `locked_by_zone` on characters:** prevents the same character from being loaded in two zone processes at once — common bug in early MMOs. Gateway sets the lock on enter-world; zone clears on logout. Stale lock recovery: gateway checks zone heartbeat, force-clears if zone is dead.

### Hot vs cold state

| State | Where it lives | Persisted how |
|---|---|---|
| Tile data | Zone memory (loaded from map file at startup) | Never written (static) |
| Player position, HP, mana, stamina | Zone memory | Batched flush every 5s + on logout |
| Inventory, equipment, gold | Zone memory | **Synchronous** write on every change |
| Skills | Zone memory | Batched every 30s + on logout |
| Dropped items, corpses | Zone memory + DB | **Synchronous** write on drop/loot/decay |
| Resource node state | Zone memory | **Synchronous** write on chop/mine; respawn ticked from memory |
| NPC state | Zone memory | Periodic snapshot every 60s; vendor stock on transaction |

**Rule of thumb:** anything involving an item or gold is synchronous to DB. Anything involving position/HP/skills is batched (we can lose 5-30s of progress to a crash without anyone caring; item duping or gold loss is unacceptable).

### Crash safety

- **Zone crash:** last batched write may be lost (≤5s of position/HP), all item/gold transactions safe. Players reconnect via gateway, character reloads at last-known position.
- **Gateway crash:** zones keep running, players in-zone stay in-zone, but no new logins or zone transitions until gateway recovers. Gateway is stateless except for zone registry — restart is fast.
- **DB crash:** everything stops. Players get a "server is down" message. On recovery, zones reload state and resume.

### Backups

- MVP: nightly `pg_dump` to a separate disk + offsite. Acceptable RPO = 24h for indie launch.
- Pre-real-launch: WAL archiving + PITR.

### Anti-dupe discipline

Item movement (inventory ↔ inventory, inventory ↔ world, inventory ↔ bank) **must** be a single DB transaction. No "delete from source then insert to dest" — that is *the* dupe bug. Use a single `UPDATE ... WHERE` that atomically reassigns ownership, or wrap in a transaction with row locks.

Trade between players: 2-phase. Both parties stage items in a trade window, both confirm, then a single transaction swaps ownership. Confirmed dupe-safe by construction.

### Not in scope

Sharding the DB, read replicas, event sourcing for audit, hot-standby failover. All post-MVP.

## Code Sharing & Repo Structure

### Repo layout

```
haxecraft/
├── shared/                  -- compiled into BOTH client and server
│   ├── proto/               -- network message classes (@:serializable)
│   ├── data/                -- item defs, skill tables, spell tables, tile flags
│   ├── math/                -- combat formulas, hit chance, dmg, skill gain
│   ├── world/               -- tile types, coord math, zone-rect helpers
│   ├── constants.hx         -- TICK_HZ, MAX_INVENTORY, etc.
│   └── build-shared.hxml
├── client/                  -- Haxe/Heaps
│   ├── src/                 -- rendering, input, UI, prediction
│   ├── res/                 -- atlases, audio, fonts, Minifantasy tiles
│   └── build-client.hxml    -- adds shared/ to classpath
├── server/                  -- HashLink native
│   ├── gateway/             -- auth, routing, zone registry
│   ├── zone/                -- simulation, tick loop, world ownership
│   ├── db/                  -- Postgres access layer
│   ├── net/                 -- TCP server, frame codec
│   └── build-*.hxml         -- one per binary (gateway, zone)
├── tools/                   -- asset pipeline, Tiled importer, dev CLIs
└── docs/
```

### Layering discipline

| Layer | Allowed dependencies |
|---|---|
| `shared/` | Haxe stdlib only. No Heaps, no `sys`, no I/O. Pure data + pure functions. |
| `client/` | shared + Heaps + hxd + UI libs |
| `server/` | shared + hl.* + hxsockets + DB driver |

**Lint rule:** anything in `shared/` must compile to JS (even though no JS build ships day one). If it doesn't, it has a platform dep and belongs elsewhere. Enforce in CI.

### Shared protocol

```haxe
@:serializable
class MoveIntent {
  public var dir : Direction;   // u8
  public var tick : Int;        // u32 (client clock for lag comp)
}
```

Same class, byte-identical serialization, compiled into both binaries. Adding a field breaks both sides to compile until updated.

### Shared math = shared tests

Combat formulas, skill-gain chance, hit-chance, damage calc all live in `shared/math/`. Server uses them authoritatively. Client uses them for predicted damage numbers and hit/miss UI tells. Tests run once and validate both sides simultaneously.

### Build pipeline

- `make client-hl` — local HL build
- `make client-js` — JS build (post-MVP)
- `make gateway` — HL native binary
- `make zone` — HL native binary
- `make all` — everything, plus runs shared/ test suite

CI on every commit: build all four, run shared tests, run a smoke test that boots gateway + 1 zone + headless client for 30s.

### Asset pipeline

`tools/` directory handles:

- **Tiled map import:** `.tmx` → packed binary tile data + spawn metadata, consumed by zone at startup
- **Sprite atlas generation:** Minifantasy sheets → consolidated atlas + index (seeded from haxecraft's `AtlasLoader`/`AtlasSheet`)
- **Spell/item/skill data:** authored as JSON in `shared/data/`, validated at build time

### Honest tradeoffs of going Haxe-everywhere

- Haxe Postgres drivers are less mature than node-pg or pgx. Likely need to write a thin wrapper around HL's native libpq binding or use a community lib and contribute back. Budget time in M0.
- Smaller hiring pool if collaborators are ever added (offset: AI-assisted dev levels this).
- Haxe ecosystem moves slower than JS/Go for general libs.

Real but small; code-sharing dividend more than pays for them.

## Testing Strategy

### Layer 1 — Unit tests (shared/)

Combat math, hit chance, damage formulas, skill-gain curves, serialization round-trip. Pure functions, fast (<10s suite), run on every commit. Validates client and server simultaneously because it lives in `shared/`.

### Layer 2 — Server simulation tests

Boot a zone in-process (no network, no DB — mock both). Drive with scripted intents: "player A swings at player B, advance 25 ticks, assert B took N damage." Tests game logic in isolation.

### Layer 3 — Integration tests

Boot real gateway + zone + Postgres (Docker) + N **headless clients** in CI. Headless client = same Haxe client code minus rendering, scriptable.

Must-have scenarios:

- Login → spawn → walk 50 tiles → logout → login → position persisted
- Two clients in same zone see each other
- Combat to death → corpse → ghost → res → return to corpse → loot recovered
- Trade with disconnect mid-trade, both clients crash mid-trade
- Drop item, second player picks up, first player crashes — no dupe, no loss
- Cast spell with no reagents — server rejects, client predicts rejection cleanly
- Move during cast — cast interrupted server-side, client cancels animation

### Layer 4 — Zone handoff tests (extra paranoia)

Handoff is the bug factory. Dedicated suite.

- Walk A→B then immediately back. State preserved.
- Crash during handoff. Reconnect lands in correct zone.
- Zone B down when player tries to cross. Gateway rejects gracefully; player stays in A.
- Two players cross same boundary on same tick.
- Player carrying high-value items crosses zones. Items present in inventory both sides — never duped, never lost.

### Layer 5 — Property/invariant tests

Continuous DB-scanning auditor process:

- No item in two `character_inventory` rows
- No item in inventory AND `world_items` simultaneously
- Sum of gold conserved within accounting
- No character HP > `max_hp_for_str`
- No character in two zones (`locked_by_zone` consistency)
- All `decay_at` timestamps are in the future or item is gone

Nightly in dev, every few minutes in production.

### Layer 6 — Load tests

Synthetic bot clients (headless + simple AI: wander, attack nearby, occasional crafting). Spin up N=100, 200, 500 to validate scale claims.

Goal: zone process holds 200 active bots at <50% CPU on a modest box.

### Layer 7 — Manual playtest

Does it *feel* like UO? Regular sessions. No CI substitute.

### CI gates

- Every push: Layers 1+2+3, <5 min total
- Every push: Layer 4 handoff suite, separately
- Nightly: Layer 5 invariant scan + Layer 6 moderate-scale load test
- Manual: Layer 7 on a cadence

### Anti-cheat is "the server is right"

Conventional cheats (speed hacks, teleport hacks, damage hacks) are impossible by construction (intents-only). What remains: exploit bugs (Layer 5 catches), botting (rate limits + manual review at launch), packet replay (handoff token signing covers worst case; full nonce protection deferred).

## MVP Milestones & Phasing

**Honest framing:** ~30 weeks of focused work to playable closed alpha on this timeline. For a 2-person effective team with normal indie life intrusions, plan 1.5× to 2× in calendar time. **9-12 months to alpha** is realistic. Public launch is well past that.

Each milestone ends with something demoable.

### M0 — Foundation (~3 weeks)

- Repo restructure to `shared/ client/ server/ tools/`
- Shared protocol skeleton: `@:serializable` macro, codec, version handshake
- HL server skeleton: TCP listen, frame I/O, basic message dispatch
- Heaps client connects, sends `Hello`, gets ack
- Postgres up (Docker for dev), schema applied
- Account create + login flow end-to-end

**Demo:** client connects, logs in, sees "Welcome."

### M1 — One player, one zone (~4 weeks)

- Zone process: 10 Hz tick loop, tile-step movement authority
- Tiled `.tmx` loader feeding zone with a placeholder 1024×1024 map (worldgen-derived)
- Client renders visible tile rect, smooth-interpolates player position
- Logout/login round-trips position
- Headless client harness scaffolded

**Demo:** walk around a procgen world in a window. State persists across logout.

### M2 — Multiple players in one zone (~3 weeks)

- Multi-client position broadcast (visible-range filtering)
- Zone-local chat + global chat (gateway-routed)
- Emotes
- Headless bots running scripted walks in CI

**Demo:** two windows on same machine, players see each other walking, chat works.

### M3 — Combat + skills + death (~4 weeks)

- Swing-timer combat (`nextSwingTick`, hit chance vs Wrestling default)
- Swordsmanship + Tactics + Anatomy + Wrestling skills, gain by use
- Monster spawner + simple AI (wander, aggro, melee)
- HP, death → corpse + ghost form
- Healer NPC resurrection in town

**Demo:** fight a wolf, get killed, ghost-walk back to town, get rezzed.

### M4 — Items, inventory, corpse loot (~3 weeks)

- Inventory grid UI (mockup style)
- Equipment slots
- Mob loot tables; pick up from corpses
- Player corpse with full loot + decay + owner-only window
- Trade UI (2-phase, dupe-safe)
- NPC banker → bank box

**Demo:** kill wolf, loot pelt, return to town, sell to vendor, bank gold.

### M5 — Gathering + crafting + economy (~3 weeks)

- Resource node entities (trees, ore veins)
- Lumberjacking + Mining skills, gather by use
- Blacksmithy + Carpentry: recipe-based crafting UI
- Quality tiers on crafted gear
- NPC vendors with stock + repair

**Demo:** chop wood, mine iron, smith a sword that's better than vendor-bought.

### M6 — Magery + reagents (~3 weeks)

- Spellbook UI
- 15 MVP spells
- Reagents, mana, cast time, movement-cancels-cast
- Magery + EvalInt skill gain
- Player resurrection (Magery 60+)

**Demo:** mage fights wolf with Magic Arrow, casts Recall to teleport home.

### M7 — Full-loot PvP + guard zones (~2 weeks)

- `GUARD_ZONE` tile flag + Guard NPC spawn-and-nuke mechanic
- Full-loot PvP outside guard zones
- Aggressor flagging (prevents griefing edge cases)

**Demo:** two players fight in wilderness; one dies, other loots corpse. Try to attack in town → guard one-shots you.

### M8 — Second zone + handoff (~3 weeks)

- Second zone process boots, registers with gateway
- Cross-zone handoff implementation (the hard part)
- **Layer-4 handoff tests must all pass before this milestone is "done"**
- Cross-zone chat
- Multi-zone load test

**Demo:** walk from zone A to zone B, fight a monster, walk back. Items preserved both directions.

### M9 — Content authoring + polish (~5 weeks)

- Hand-author starter town (in Tiled) with vendors, banker, healer, guards
- Hand-author 2 dungeons with monsters, named bosses (no special boss mechanics — just hard monsters)
- Keyword-dialogue NPCs (10-20, with one-line lore)
- Sound effects, music loops, UI polish
- Closed alpha onboarding flow
- Bug fixing + balance

**Demo:** closed-alpha-ready build. Invite 5-10 friends.

## What This Is Not

- Not public-launch ready at M9. That is closed alpha. Public launch = 6+ more months of content, polish, anti-grief, ops.
- Not housing. First big post-alpha feature.
- Not reputation system. Guard zones cover for it. Reputation is a post-alpha mechanic that unfolds with full PvP economy.
- Not sharded — single zone process per region, with the *capability* to add zones. Real horizontal scaling beyond M8 is post-alpha tuning.

## Major Risks

- **Zone handoff bugs in production.** Mitigated by paranoid testing (Layer 4), but expect to ship a patch in week 1 of public play.
- **Item dupes via clever timing.** Mitigated by transaction discipline + Layer 5 invariants, but assume one will be found.
- **HashLink Postgres driver maturity.** May need to write/extend a lib in M0. Could add 1-2 weeks.
- **Content authoring being a wall.** Tiled is great but painting 1024×1024 of detailed terrain is real work. Mitigated by procgen base layer + hand-edit; expect M1 and M9 to drag.
- **Burnout.** 9-12 months on a side-project with no public feedback is hard. M9 closed alpha is partly to *get* feedback before burnout hits.

## UI / Aesthetic Direction

- **Art:** Minifantasy library (or matching style). 8×8 native pixel art. Saves enormous original-art work for MVP.
- **HUD shape:** persistent top bar (tabs for inventory, stats, etc.), grid-slot inventory panel docked right, chat docked bottom-left with input line, two-line minimum chat visible by default with named/colored handles.
- **Chat is first-class:** core UI from day one. Includes emotes, zone-local, global, party.

## Decision Log (the calls made in brainstorm)

| Question | Decision |
|---|---|
| Project relation to haxecraft | Evolve from A → C: start by adding multiplayer to haxecraft; engine becomes foundation for a different MMO over time |
| Scale target | C with room to scale to D: 100-500 CCU launch, sharded path to 1000+ |
| Intent | Indie ship (option B): real players eventually, indie timescale, plan migrations |
| Game type | B (classic 2D MMORPG) + D (social/creative), specifically UO 1999-inspired |
| Team | Joshua-led, AI as implementation partner |
| UO pillars | Skill/combat/magic/death/economy/PvP/world all CORE; housing & reputation LATER; living-world content elevated from LATER to CORE; UO didn't have quests |
| Server language | A — Haxe on server, HashLink target |
| Architecture | Approach 2 — gateway + zone processes from day one |
| Tile size | 8×8 px (correction from initial 16×16 assumption) |
| Movement model | C — tile-step authority, smooth-interp rendering |
| Art direction | Minifantasy-style |
