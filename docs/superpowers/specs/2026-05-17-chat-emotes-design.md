# Chat + Emotes — Design

**Date:** 2026-05-17
**Status:** Approved (design); pending implementation plan

## Context

This is the second of three sub-projects for milestone **M2 — Multiple
players in one zone**:

1. Interest management — *done* (merged to `master`)
2. **Chat + emotes** ← *this spec*
3. CI + headless bots

The game has no chat: the protocol message catalog (`shared/src/shared/proto/`)
has no chat type, and the client has no chat UI. Players can see each other
move (interest management) but cannot communicate.

Two facts shape the design:

- The client keeps **both** connections open while in a zone — the gateway
  connection (`Main` polls it every frame) and the zone connection. So global
  chat can route through the gateway and zone-local chat through the zone,
  with no new gateway↔zone link.
- Interest management already maintains, per observer, the set of entity IDs
  in that observer's ~64-tile area of interest. Zone-local "say" reuses it.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Zone-local routing | Within interest range (reuse `InterestManager`) |
| Emotes | Text emotes — freeform `/me` plus a canned set |
| Chat UI | Minimal — input line + last ~3 messages, single color, text channel prefixes |
| Message shape | One `MsgChat` with a `channel` field; dual-path routing |
| Command parsing | Client-side; servers route by `channel`, never parse `/`-commands |

## Scope

**In scope:** the `MsgChat` protocol message; client command parsing and a
minimal chat box; zone routing of `SAY`/`EMOTE` via interest range; gateway
routing of `GLOBAL`; the canned emote set.

**Out of scope:** party chat (no grouping system exists); chat scrollback,
channel tabs, colored styling; animated sprite emotes; chat persistence/history
across sessions; profanity filtering.

## Section 1 — Protocol

New additions in `shared/src/shared/proto/`:

- `MsgType.CHAT = 40` — a new value in the enum abstract (M0 used 1–5, M1
  10–23, SP2 30–31; chat opens a new band at 40).
- `ChatChannel` — an `enum abstract ChatChannel(Int)`: `SAY = 0`,
  `GLOBAL = 1`, `EMOTE = 2`.
- `MsgChat` — built with the existing `@:serializable` macro, fields:
  - `channel:Int` — a `ChatChannel` value.
  - `senderName:String` — the display name. Empty on a client→server message;
    the server fills it from the connection's authenticated identity, so a
    client cannot spoof another player's name.
  - `text:String` — the message body.

  `MsgChat` is used in both directions; the same type carries a client's
  outbound message and the server's broadcast.

## Section 2 — Client: command parsing & chat box

**`ChatCommandParser`** (`client/src/client/ui/ChatCommandParser.hx`) — a pure
function `parse(input:String):{channel:Int, text:String}`:

- `/g <msg>` → `GLOBAL`, text = the remainder.
- `/me <action>` → `EMOTE`, text = the action.
- `/wave`, `/bow`, `/laugh`, `/cheer`, `/dance` → `EMOTE`, text from a canned
  table (`wave → "waves."`, `bow → "bows."`, `laugh → "laughs."`,
  `cheer → "cheers!"`, `dance → "dances."`).
- anything else → `SAY`, text = the whole input.

Being a pure function, it is unit-testable headlessly.

**`ChatBox`** (`client/src/client/ui/ChatBox.hx`) — an `h2d.Object` overlay
docked bottom-left, created when the client enters the zone:

- Shows the last 3 received messages as `h2d.Text` lines (Heaps `DefaultFont`,
  as `LoginScreen` uses).
- An input line, hidden until activated. `Enter` opens it; `ETextInput` events
  append characters; `Backspace` deletes; `Enter` submits and closes; `Escape`
  cancels and closes.
- Single color. Each rendered line carries a text prefix so channels are
  distinguishable without color: `Name: text` (say), `[g] Name: text`
  (global), `* Name text` (emote), `text` (system messages).
- `public var inputActive:Bool` — true while the input line is open.

**Send path:** on submit, `Main` runs `ChatCommandParser.parse`; an empty or
whitespace-only `text` is ignored. `SAY`/`EMOTE` are sent on the **zone**
socket, `GLOBAL` on the **gateway** socket, both as `MsgChat` with
`senderName` empty.

**Keyboard capture:** `Main` routes key events to `ChatBox` while in the zone,
and skips `InputDispatcher.update()` whenever `chatBox.inputActive` is true, so
typing `w`/`a`/`s`/`d` into chat does not walk the player.

**Receive path:** a `CHAT` handler is registered on **both** the gateway and
zone client dispatchers; it deserializes `MsgChat` and appends a formatted
line to the `ChatBox`.

## Section 3 — Zone routing (SAY / EMOTE)

The zone registers a `ChatHandler` (`server/src/server/zone/ChatHandler.hx`)
for `MsgType.CHAT`. On a message:

1. Resolve the sender entity from the connection (via
   `EnterZoneHandler.entityIdForConn`). If the connection has no entity, drop
   the message.
2. Fill `senderName` from the sender entity; truncate `text` to 200 characters.
3. Broadcast the `MsgChat` to the sender's own connection **plus** every entity
   whose interest known-set contains the sender.

This needs a new `InterestManager.observersOf(entityId:Int):Array<Int>` —
returns the observer IDs whose known-set currently contains the entity.
`EMOTE` routes identically to `SAY`; the only difference is the `channel`
value the client renders. The zone never inspects `text` for `/`-commands.

## Section 4 — Gateway routing (GLOBAL)

The gateway gains a `conn → playerName` registry. `LoginHandler` records the
entry on a successful login; the gateway's connection loop removes it when a
connection drops.

The gateway registers a `CHAT` handler. On a `GLOBAL` message from a
connection present in the registry, it fills `senderName` from the registry,
truncates `text` to 200 characters, and broadcasts the `MsgChat` to every
connection in the registry. A `GLOBAL` message from a connection not in the
registry (not logged in) is dropped.

## Section 5 — Error handling & testing

**Error handling:**

- Empty or whitespace-only `text` — ignored client-side, never sent.
- `text` longer than 200 characters — truncated server-side (zone and gateway).
- Chat from an unidentified connection — zone: no sender entity; gateway: not
  in the registry — silently dropped, no crash.

**Testing:**

- *Unit (shared-test):* `MsgChat` serialize/round-trip, alongside the existing
  message tests.
- *Unit (client-test):* `ChatCommandParser` — `/g`, `/me`, each canned emote
  command, and plain text resolve to the correct `channel` and `text`.
- *Integration (server-test):* two `HeadlessClient`s — a `SAY` reaches a
  nearby client and not a distant one (reusing interest range); a `GLOBAL`
  reaches the other client regardless of distance; a `/wave` reaches a nearby
  client as an `EMOTE`. `HeadlessClient` gains a `sendChat(channel, text)`
  helper; messages are observed via the existing `drainFrames`.
- *Regression:* the existing zone, interest, and items integration tests stay
  green.

## Risks

- **Gateway connection lifetime.** Global chat assumes the client keeps its
  gateway connection alive for the whole session. It does today (`Main` polls
  it every frame). If that ever changes, global chat needs revisiting.
- **`senderName` from identity.** The server filling `senderName` (rather than
  trusting the client) is what prevents name spoofing — the plan must wire it
  from the authenticated entity/registry, not echo the client's field.

## Sub-project boundary

This sub-project is complete when players can send `SAY`/`EMOTE` to nearby
players and `GLOBAL` to everyone online, a minimal chat box shows incoming
messages and captures typed input, the canned emotes work, and all tests pass.
CI + headless bots follows as the final M2 sub-project.
