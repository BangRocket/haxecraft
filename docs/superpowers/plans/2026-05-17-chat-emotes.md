# Chat + Emotes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add zone-local ("say") chat, global chat, and text emotes — players can talk to nearby players, broadcast to everyone online, and emote.

**Architecture:** One `MsgChat` message with a `channel` field. The client parses `/`-commands locally and sends `SAY`/`EMOTE` on the zone connection, `GLOBAL` on the gateway connection. The zone routes `SAY`/`EMOTE` to the sender plus everyone whose `InterestManager` known-set contains them; the gateway broadcasts `GLOBAL` to all logged-in connections. A minimal chat box renders incoming messages and captures typed input.

**Tech Stack:** Haxe 4.3, HashLink (HLC native on Apple Silicon), Heaps (`h2d`), utest.

**Spec:** `docs/superpowers/specs/2026-05-17-chat-emotes-design.md`

---

## File Structure

**New files:**
- `shared/src/shared/proto/ChatChannel.hx` — the `SAY`/`GLOBAL`/`EMOTE` enum.
- `shared/src/shared/proto/MsgChat.hx` — the chat message.
- `client/src/client/ui/ChatCommandParser.hx` — parses `/`-commands; canned emote table.
- `client/src/client/ui/ChatBox.hx` — the minimal chat overlay.
- `client/test/TestChatCommandParser.hx` — parser unit tests.
- `server/src/server/zone/ChatHandler.hx` — zone routing of `SAY`/`EMOTE`.
- `server/src/server/gateway/GatewayPlayers.hx` — gateway `conn → name` registry.
- `server/src/server/gateway/GatewayChatHandler.hx` — gateway routing of `GLOBAL`.
- `server/test/TestZoneChat.hx` — two-client integration test.

**Modified files:**
- `shared/src/shared/proto/MsgType.hx` — add `CHAT = 40`.
- `shared/test/TestMessages.hx` — `MsgChat` round-trip test.
- `server/src/server/zone/InterestManager.hx` — add `observersOf`.
- `server/test/TestInterestManager.hx` — `observersOf` unit test.
- `server/src/server/zone/Main.hx` — register the zone `ChatHandler`.
- `server/src/server/gateway/LoginHandler.hx` — record players in the registry.
- `server/src/server/gateway/Main.hx` — registry, `GatewayChatHandler`, disconnect cleanup.
- `client/src/client/Main.hx` — chat box, both-dispatcher `CHAT` handler, input capture, send path.
- `client/src/headless/HeadlessClient.hx` — `sendChat` + `drainGatewayFrames`.
- `client/test/TestMain.hx` — register `TestChatCommandParser`.
- `server/test/TestMain.hx` — register `TestZoneChat`.

---

## Task 1: `MsgChat` protocol

**Files:**
- Create: `shared/src/shared/proto/ChatChannel.hx`, `shared/src/shared/proto/MsgChat.hx`
- Modify: `shared/src/shared/proto/MsgType.hx`
- Test: `shared/test/TestMessages.hx`

- [ ] **Step 1: Write the failing test**

In `shared/test/TestMessages.hx`, add the import at the top alongside the others:

```haxe
import shared.proto.MsgChat;
```

Add this test method to the `TestMessages` class:

```haxe
  function testChat() {
    var m = new MsgChat();
    m.channel = 2;
    m.senderName = "Bob";
    m.text = "waves.";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgChat.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(2, m2.channel);
    Assert.equals("Bob", m2.senderName);
    Assert.equals("waves.", m2.text);
  }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `make test`
Expected: FAIL — compile error, `shared.proto.MsgChat` not found.

- [ ] **Step 3: Create `ChatChannel` and `MsgChat`, add the `MsgType`**

Create `shared/src/shared/proto/ChatChannel.hx`:

```haxe
package shared.proto;

enum abstract ChatChannel(Int) to Int from Int {
  var SAY = 0;
  var GLOBAL = 1;
  var EMOTE = 2;
}
```

Create `shared/src/shared/proto/MsgChat.hx`:

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgChat implements Serializable {
  public var channel:Int = 0;     // a ChatChannel value
  public var senderName:String = "";  // empty client->server; server fills it
  public var text:String = "";
  public function new() {}
}
```

In `shared/src/shared/proto/MsgType.hx`, add after the `WORLD_OBJECT_SPAWN = 31;` line:

```haxe
  // M2 SP2: chat
  var CHAT = 40;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test`
Expected: PASS — `ALL TESTS OK`, `TestMessages.testChat` green.

- [ ] **Step 5: Commit**

```bash
git add shared/src/shared/proto/ChatChannel.hx shared/src/shared/proto/MsgChat.hx shared/src/shared/proto/MsgType.hx shared/test/TestMessages.hx
git commit -m "feat(proto): MsgChat message + ChatChannel

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `ChatCommandParser`

**Files:**
- Create: `client/src/client/ui/ChatCommandParser.hx`
- Create: `client/test/TestChatCommandParser.hx`
- Modify: `client/test/TestMain.hx`

- [ ] **Step 1: Write the failing tests**

Create `client/test/TestChatCommandParser.hx`:

```haxe
package;

import utest.Test;
import utest.Assert;
import client.ui.ChatCommandParser;
import shared.proto.ChatChannel;

class TestChatCommandParser extends Test {
  function testPlainTextIsSay() {
    var r = ChatCommandParser.parse("hello there");
    Assert.equals((ChatChannel.SAY : Int), r.channel);
    Assert.equals("hello there", r.text);
  }

  function testGlobalCommand() {
    var r = ChatCommandParser.parse("/g anyone online?");
    Assert.equals((ChatChannel.GLOBAL : Int), r.channel);
    Assert.equals("anyone online?", r.text);
  }

  function testMeEmote() {
    var r = ChatCommandParser.parse("/me ponders the void");
    Assert.equals((ChatChannel.EMOTE : Int), r.channel);
    Assert.equals("ponders the void", r.text);
  }

  function testCannedEmote() {
    var r = ChatCommandParser.parse("/wave");
    Assert.equals((ChatChannel.EMOTE : Int), r.channel);
    Assert.equals("waves.", r.text);
  }

  function testUnknownSlashIsSay() {
    var r = ChatCommandParser.parse("/notacommand hi");
    Assert.equals((ChatChannel.SAY : Int), r.channel);
    Assert.equals("/notacommand hi", r.text);
  }
}
```

Register it in `client/test/TestMain.hx` — add after the `TestSpriteCatalog` line:

```haxe
    r.addCase(new TestSpriteCatalog());
    r.addCase(new TestChatCommandParser());
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./build_native.sh client-test`
Expected: FAIL — compile error, `client.ui.ChatCommandParser` not found.

- [ ] **Step 3: Implement `ChatCommandParser`**

Create `client/src/client/ui/ChatCommandParser.hx`:

```haxe
package client.ui;

import shared.proto.ChatChannel;

/** Parses a typed chat line into a channel + body. Pure — no I/O. */
class ChatCommandParser {
  /** Canned emote command -> action text. */
  public static var CANNED_EMOTES(default, null):Map<String, String> = [
    "wave"  => "waves.",
    "bow"   => "bows.",
    "laugh" => "laughs.",
    "cheer" => "cheers!",
    "dance" => "dances.",
  ];

  public static function parse(input:String):{channel:Int, text:String} {
    if (input.charAt(0) != "/") {
      return { channel: (ChatChannel.SAY : Int), text: input };
    }
    var sp = input.indexOf(" ");
    var cmd = (sp < 0 ? input.substr(1) : input.substring(1, sp));
    var rest = (sp < 0 ? "" : input.substr(sp + 1));

    if (cmd == "g") {
      return { channel: (ChatChannel.GLOBAL : Int), text: rest };
    }
    if (cmd == "me") {
      return { channel: (ChatChannel.EMOTE : Int), text: rest };
    }
    if (CANNED_EMOTES.exists(cmd)) {
      return { channel: (ChatChannel.EMOTE : Int), text: CANNED_EMOTES.get(cmd) };
    }
    // Unknown command — treat the whole line as say text.
    return { channel: (ChatChannel.SAY : Int), text: input };
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./build_native.sh client-test && ./bin/client-test`
Expected: PASS — `ALL TESTS OK`, 5 `TestChatCommandParser` cases green.

- [ ] **Step 5: Commit**

```bash
git add client/src/client/ui/ChatCommandParser.hx client/test/TestChatCommandParser.hx client/test/TestMain.hx
git commit -m "feat(client): ChatCommandParser — /-command + emote parsing

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Zone chat routing

**Files:**
- Modify: `server/src/server/zone/InterestManager.hx`
- Create: `server/src/server/zone/ChatHandler.hx`
- Modify: `server/src/server/zone/Main.hx`
- Test: `server/test/TestInterestManager.hx`

- [ ] **Step 1: Write the failing test for `observersOf`**

In `server/test/TestInterestManager.hx`, add this test method to the `TestInterestManager` class:

```haxe
  function testObserversOfReturnsKnowers() {
    var im = new InterestManager();
    var a = ch(1, 0, 0);
    var b = ch(2, 10, 0);
    var c = ch(3, 500, 0);
    im.update([a, b, c]);                 // a<->b mutually known; c far from both
    var obs = im.observersOf(1);          // who knows entity 1?
    Assert.isTrue(obs.indexOf(2) >= 0);   // b knows a
    Assert.isFalse(obs.indexOf(3) >= 0);  // c does not
    Assert.isFalse(obs.indexOf(1) >= 0);  // never includes self
  }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./build_native.sh server-test`
Expected: FAIL — compile error, `observersOf` not a field of `InterestManager`.

- [ ] **Step 3: Add `observersOf` to `InterestManager`**

In `server/src/server/zone/InterestManager.hx`, add this method after `forget`:

```haxe
  /** Observer IDs whose known-set currently contains `entityId` (excludes self). */
  public function observersOf(entityId:Int):Array<Int> {
    var out:Array<Int> = [];
    for (obsId in known.keys()) {
      if (obsId == entityId) continue;
      var s = known.get(obsId);
      if (s.exists(entityId)) out.push(obsId);
    }
    return out;
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./build_native.sh server-test && ./bin/server-test`
Expected: `TestInterestManager` — all cases green including `testObserversOfReturnsKnowers`. (`TestLoginFlow`/`TestZoneLifecycle`/etc. error without a live server — not this task's concern.)

- [ ] **Step 5: Create the zone `ChatHandler`**

Create `server/src/server/zone/ChatHandler.hx`:

```haxe
package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgChat;
import shared.proto.MsgType;

/** Routes SAY / EMOTE chat to the sender and everyone in their interest range. */
class ChatHandler {
  static inline var MAX_TEXT = 200;

  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;
  var interest:InterestManager;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler, interest:InterestManager) {
    this.sim = sim;
    this.enterHandler = enterHandler;
    this.interest = interest;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return;                       // not in the zone — drop
    var sender = sim.entityById(entId);
    if (sender == null) return;

    var m = MsgChat.deserialize(new BytesInput(payload));
    m.senderName = sender.name;                      // authoritative — never trust the client field
    if (m.text.length > MAX_TEXT) m.text = m.text.substr(0, MAX_TEXT);

    var out = new BytesOutput(); m.serialize(out);
    var bytes = out.getBytes();

    if (sender.conn != null && sender.conn.alive) {
      sender.conn.sendFrame(MsgType.CHAT, bytes);
    }
    for (obsId in interest.observersOf(entId)) {
      var obs = sim.entityById(obsId);
      if (obs != null && obs.conn != null && obs.conn.alive) {
        obs.conn.sendFrame(MsgType.CHAT, bytes);
      }
    }
  }
}
```

- [ ] **Step 6: Register the `ChatHandler` in the zone**

In `server/src/server/zone/Main.hx`, after the `moveHandler` line:

```haxe
    var moveHandler = new MoveIntentHandler(sim, enterHandler, interest);
```

add:

```haxe
    var chatHandler = new ChatHandler(sim, enterHandler, interest);
```

Then after the existing `dispatcher.register(MsgType.MOVE_INTENT, moveHandler.handle);` line, add:

```haxe
    dispatcher.register(MsgType.CHAT, chatHandler.handle);
```

- [ ] **Step 7: Build the zone**

Run: `./build_native.sh zone server-test`
Expected: `clang -> bin/zone` and `clang -> bin/server-test`, exit 0.

- [ ] **Step 8: Commit**

```bash
git add server/src/server/zone/InterestManager.hx server/src/server/zone/ChatHandler.hx server/src/server/zone/Main.hx server/test/TestInterestManager.hx
git commit -m "feat(zone): route SAY/EMOTE chat through interest range

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Gateway global-chat routing

**Files:**
- Create: `server/src/server/gateway/GatewayPlayers.hx`, `server/src/server/gateway/GatewayChatHandler.hx`
- Modify: `server/src/server/gateway/LoginHandler.hx`, `server/src/server/gateway/Main.hx`

- [ ] **Step 1: Create the `GatewayPlayers` registry**

Create `server/src/server/gateway/GatewayPlayers.hx`:

```haxe
package server.gateway;

import server.net.ClientConnection;

private typedef Entry = { conn:ClientConnection, name:String };

/** Tracks logged-in gateway connections so global chat can reach them. */
class GatewayPlayers {
  var byConn:Map<Int, Entry> = new Map();

  public function new() {}

  public function add(conn:ClientConnection, name:String):Void {
    byConn.set(conn.id, { conn: conn, name: name });
  }

  public function remove(connId:Int):Void {
    byConn.remove(connId);
  }

  public function nameOf(connId:Int):Null<String> {
    var e = byConn.get(connId);
    return e == null ? null : e.name;
  }

  public function all():Iterator<Entry> {
    return byConn.iterator();
  }
}
```

- [ ] **Step 2: Record players in `LoginHandler`**

In `server/src/server/gateway/LoginHandler.hx`, add a field and constructor parameter. Replace the fields-and-constructor block:

```haxe
  var accountDal:AccountDal;
  var characterDal:CharacterDal;
  var sessions:SessionStore;

  public function new(accountDal:AccountDal, characterDal:CharacterDal, sessions:SessionStore) {
    this.accountDal = accountDal;
    this.characterDal = characterDal;
    this.sessions = sessions;
  }
```

with:

```haxe
  var accountDal:AccountDal;
  var characterDal:CharacterDal;
  var sessions:SessionStore;
  var players:GatewayPlayers;

  public function new(accountDal:AccountDal, characterDal:CharacterDal, sessions:SessionStore, players:GatewayPlayers) {
    this.accountDal = accountDal;
    this.characterDal = characterDal;
    this.sessions = sessions;
    this.players = players;
  }
```

Then, in `handle`, immediately after the success-path `Sys.println('[gateway] conn ${conn.id} login OK ...')` line, add:

```haxe
    players.add(conn, acct.username);
```

- [ ] **Step 3: Create the `GatewayChatHandler`**

Create `server/src/server/gateway/GatewayChatHandler.hx`:

```haxe
package server.gateway;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgChat;
import shared.proto.ChatChannel;
import shared.proto.MsgType;

/** Broadcasts GLOBAL chat to every logged-in gateway connection. */
class GatewayChatHandler {
  static inline var MAX_TEXT = 200;

  var players:GatewayPlayers;

  public function new(players:GatewayPlayers) {
    this.players = players;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var m = MsgChat.deserialize(new BytesInput(payload));
    if (m.channel != (ChatChannel.GLOBAL : Int)) return;   // gateway only routes GLOBAL

    var name = players.nameOf(conn.id);
    if (name == null) return;                              // not logged in — drop

    m.senderName = name;
    if (m.text.length > MAX_TEXT) m.text = m.text.substr(0, MAX_TEXT);

    var out = new BytesOutput(); m.serialize(out);
    var bytes = out.getBytes();
    for (p in players.all()) {
      if (p.conn.alive) p.conn.sendFrame(MsgType.CHAT, bytes);
    }
  }
}
```

- [ ] **Step 4: Wire the registry + handler into the gateway**

In `server/src/server/gateway/Main.hx`, replace:

```haxe
    var sessions = new SessionStore();
    var loginHandler = new LoginHandler(accountDal, characterDal, sessions);
    dispatcher.register(MsgType.LOGIN, loginHandler.handle);
```

with:

```haxe
    var sessions = new SessionStore();
    var players = new GatewayPlayers();
    var loginHandler = new LoginHandler(accountDal, characterDal, sessions, players);
    dispatcher.register(MsgType.LOGIN, loginHandler.handle);
    var chatHandler = new GatewayChatHandler(players);
    dispatcher.register(MsgType.CHAT, chatHandler.handle);
```

Then, in the dead-connection branch, replace:

```haxe
        if (!c.alive) {
          c.close();
          srv.connections.splice(i, 1);
        } else {
```

with:

```haxe
        if (!c.alive) {
          players.remove(c.id);
          c.close();
          srv.connections.splice(i, 1);
        } else {
```

- [ ] **Step 5: Build the gateway**

Run: `./build_native.sh gateway`
Expected: `clang -> bin/gateway`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add server/src/server/gateway/GatewayPlayers.hx server/src/server/gateway/GatewayChatHandler.hx server/src/server/gateway/LoginHandler.hx server/src/server/gateway/Main.hx
git commit -m "feat(gateway): broadcast GLOBAL chat to logged-in connections

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Client chat box

**Files:**
- Create: `client/src/client/ui/ChatBox.hx`
- Modify: `client/src/client/Main.hx`

- [ ] **Step 1: Create the `ChatBox`**

Create `client/src/client/ui/ChatBox.hx`:

```haxe
package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.Event;
import hxd.res.DefaultFont;

/**
 * Minimal chat overlay docked bottom-left of the 320x240 logical screen.
 * Shows the last few messages; an input line opens on Enter.
 */
class ChatBox extends Object {
  static inline var MAX_LINES = 3;

  public var inputActive(default, null):Bool = false;
  public var onSubmit:String -> Void;

  var lines:Array<String> = [];
  var lineTexts:Array<Text> = [];
  var inputText:Text;
  var inputValue:String = "";

  public function new(parent:Object) {
    super(parent);
    var font = DefaultFont.get();
    for (i in 0...MAX_LINES) {
      var t = new Text(font, this);
      t.setScale(0.5);
      t.x = 4;
      t.y = 200 + i * 11;
      lineTexts.push(t);
    }
    inputText = new Text(font, this);
    inputText.setScale(0.5);
    inputText.x = 4;
    inputText.y = 200 + MAX_LINES * 11;
    inputText.visible = false;
    refresh();
  }

  public function addMessage(s:String):Void {
    lines.push(s);
    if (lines.length > MAX_LINES) lines.shift();
    refresh();
  }

  public function handleKey(e:Event):Void {
    if (!inputActive) {
      if (e.kind == EKeyDown && e.keyCode == hxd.Key.ENTER) {
        inputActive = true;
        inputValue = "";
        inputText.visible = true;
        refresh();
      }
      return;
    }
    switch e.kind {
      case EKeyDown:
        switch e.keyCode {
          case hxd.Key.ENTER:
            var v = inputValue;
            closeInput();
            if (v.length > 0 && onSubmit != null) onSubmit(v);
          case hxd.Key.ESCAPE:
            closeInput();
          case hxd.Key.BACKSPACE:
            if (inputValue.length > 0) {
              inputValue = inputValue.substr(0, inputValue.length - 1);
              refresh();
            }
          default:
        }
      case ETextInput:
        if (e.charCode > 31 && e.charCode < 127) {
          inputValue += String.fromCharCode(e.charCode);
          refresh();
        }
      default:
    }
  }

  function closeInput():Void {
    inputActive = false;
    inputValue = "";
    inputText.visible = false;
    refresh();
  }

  function refresh():Void {
    for (i in 0...MAX_LINES) {
      lineTexts[i].text = (i < lines.length) ? lines[i] : "";
    }
    inputText.text = "> " + inputValue + "_";
  }
}
```

- [ ] **Step 2: Wire the chat box into `Main`**

In `client/src/client/Main.hx`:

1. Add imports after the existing `client.ui` imports:

```haxe
import client.ui.ChatBox;
import client.ui.ChatCommandParser;
import shared.proto.MsgChat;
import shared.proto.ChatChannel;
```

2. Add a field after `inputDispatcher`:

```haxe
  var chatBox:ChatBox;
```

3. In `init()`, register the `CHAT` handler on both dispatchers — add to the `gatewayDispatcher` group:

```haxe
    gatewayDispatcher.on(MsgType.CHAT, onChat);
```

and to the `zoneDispatcher` group:

```haxe
    zoneDispatcher.on(MsgType.CHAT, onChat);
```

4. In `transitionToInZone()`, after the `inputDispatcher = ...` line, add:

```haxe
    chatBox = new ChatBox(s2d);
    chatBox.onSubmit = onChatSubmit;
```

5. In `onEvent`, after the `LOGGING_IN` branch, add an `IN_ZONE` branch:

```haxe
  function onEvent(e:Event):Void {
    if (state == LOGGING_IN && loginScreen != null && loginScreen.parent != null) {
      loginScreen.handleKey(e);
    } else if (state == IN_ZONE && chatBox != null) {
      chatBox.handleKey(e);
    }
  }
```

6. Add the send and receive methods (place them after `onWorldObjectSpawn`):

```haxe
  function onChatSubmit(raw:String):Void {
    var parsed = ChatCommandParser.parse(raw);
    if (StringTools.trim(parsed.text).length == 0) return;
    var m = new MsgChat();
    m.channel = parsed.channel;
    m.senderName = "";
    m.text = parsed.text;
    var out = new BytesOutput(); m.serialize(out);
    if (parsed.channel == (ChatChannel.GLOBAL : Int)) {
      if (gatewayConn != null) gatewayConn.sendFrame(MsgType.CHAT, out.getBytes());
    } else {
      if (zoneConn != null) zoneConn.sendFrame(MsgType.CHAT, out.getBytes());
    }
  }

  function onChat(payload:Bytes):Void {
    if (chatBox == null) return;
    var m = MsgChat.deserialize(new BytesInput(payload));
    var line = switch ((m.channel : ChatChannel)) {
      case SAY:    '${m.senderName}: ${m.text}';
      case GLOBAL: '[g] ${m.senderName}: ${m.text}';
      case EMOTE:  '* ${m.senderName} ${m.text}';
    }
    chatBox.addMessage(line);
  }
```

7. In `update()`, gate movement input on the chat box. Replace:

```haxe
      if (inputDispatcher != null) inputDispatcher.update();
```

with:

```haxe
      if (inputDispatcher != null && (chatBox == null || !chatBox.inputActive)) {
        inputDispatcher.update();
      }
```

- [ ] **Step 3: Build the client**

Run: `./build_native.sh client`
Expected: `clang -> bin/client`, exit 0.

- [ ] **Step 4: Eyes-on verification**

Start the server, create two accounts, and launch two clients:

```bash
./run-server.sh                                    # terminal 1 — wait for "listening on 127.0.0.1:7778"
./bin/server-cli create-account alice hunter2      # if needed
./bin/server-cli create-account bob   hunter2      # if needed
./run-client.sh                                    # terminal 2 — log in as alice
./run-client.sh                                    # terminal 3 — log in as bob
```

Expected:
- Press `Enter` — an input line (`> _`) appears bottom-left; typing does not move the player.
- Type a message, `Enter` — it appears in alice's chat box as `alice: <message>`.
- If bob is standing near alice, bob's chat box shows it; if bob walks far away, new `say` messages stop reaching him.
- `/g hello` — reaches bob regardless of distance, shown as `[g] alice: hello`.
- `/wave` — shows `* alice waves.` to nearby players.
- `Escape` while typing cancels the input line.

(The chat text scale/position is `setScale(0.5)` at the bottom-left — if it reads too small or too large, that is a one-line tune in `ChatBox`, not a logic bug.)

- [ ] **Step 5: Commit**

```bash
git add client/src/client/ui/ChatBox.hx client/src/client/Main.hx
git commit -m "feat(client): minimal chat box + send/receive wiring

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Integration test

**Files:**
- Modify: `client/src/headless/HeadlessClient.hx`
- Create: `server/test/TestZoneChat.hx`
- Modify: `server/test/TestMain.hx`

- [ ] **Step 1: Add `sendChat` and `drainGatewayFrames` to `HeadlessClient`**

In `client/src/headless/HeadlessClient.hx`, add the import after the existing `shared.proto` imports:

```haxe
import shared.proto.MsgChat;
```

Add these two methods after `drainFrames` (before `close`):

```haxe
  /** Send a chat message: GLOBAL goes via the gateway socket, others via zone. **/
  public function sendChat(channel:Int, text:String):Void {
    var m = new MsgChat();
    m.channel = channel;
    m.senderName = "";
    m.text = text;
    var sock = (channel == (shared.proto.ChatChannel.GLOBAL : Int)) ? gateway : zone;
    writeFrame(sock, MsgType.CHAT, m);
  }

  /** Like drainFrames, but reads the gateway socket (for global chat). **/
  public function drainGatewayFrames(durationS:Float):Array<{msgType:Int, payload:Bytes}> {
    var out:Array<{msgType:Int, payload:Bytes}> = [];
    var deadline = haxe.Timer.stamp() + durationS;
    while (haxe.Timer.stamp() < deadline) {
      gateway.setTimeout(0.05);
      try {
        var f = FrameCodec.readFrame(gateway.input);
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

Create `server/test/TestZoneChat.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;
import shared.proto.MsgType;
import shared.proto.MsgChat;
import shared.proto.ChatChannel;
import haxe.io.BytesInput;
import HeadlessClient;

class TestZoneChat extends Test {
  var db:DbClient;
  var accountDal:AccountDal;
  var userA:String = "test_chat_a";
  var userB:String = "test_chat_b";
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

  function loginClient(user:String):HeadlessClient {
    var c = new HeadlessClient();
    c.connectGateway();
    Assert.isTrue(c.login(user, pw));
    return c;
  }

  // True if any CHAT frame in `frames` has the given channel and text.
  static function sawChat(frames:Array<{msgType:Int, payload:haxe.io.Bytes}>, channel:Int, text:String):Bool {
    for (f in frames) if (f.msgType == (MsgType.CHAT : Int)) {
      var m = MsgChat.deserialize(new BytesInput(f.payload));
      if (m.channel == channel && m.text == text) return true;
    }
    return false;
  }

  function testNearbySayAndEmoteReach() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 306, 512);              // ~6 tiles apart — inside interest range
    cA.enterZone();
    cB.enterZone();
    Sys.sleep(0.4);                      // let interest ticks register both

    cA.sendChat((ChatChannel.SAY : Int), "hello bob");
    Assert.isTrue(sawChat(cB.drainFrames(0.6), (ChatChannel.SAY : Int), "hello bob"),
      "nearby B should receive A's say");

    cA.sendChat((ChatChannel.EMOTE : Int), "waves.");
    Assert.isTrue(sawChat(cB.drainFrames(0.6), (ChatChannel.EMOTE : Int), "waves."),
      "nearby B should receive A's emote");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }

  function testDistantSayDoesNotReachButGlobalDoes() {
    var cA = loginClient(userA);
    var cB = loginClient(userB);
    plant(userA, 300, 512);
    plant(userB, 800, 512);              // 500 tiles apart — far beyond interest range
    cA.enterZone();
    cB.enterZone();
    Sys.sleep(0.4);

    cA.sendChat((ChatChannel.SAY : Int), "psst");
    Assert.isFalse(sawChat(cB.drainFrames(0.6), (ChatChannel.SAY : Int), "psst"),
      "distant B must not receive A's say");

    cA.sendChat((ChatChannel.GLOBAL : Int), "anyone there");
    Assert.isTrue(sawChat(cB.drainGatewayFrames(0.6), (ChatChannel.GLOBAL : Int), "anyone there"),
      "distant B should receive A's global chat");

    cA.close();
    cB.close();
    Sys.sleep(0.7);
  }
}
```

Register it in `server/test/TestMain.hx` — add after the `TestZoneInterest` line:

```haxe
    r.addCase(new TestZoneInterest());
    r.addCase(new TestZoneChat());
```

- [ ] **Step 3: Run the full integration suite**

First clear any stale server processes (a zone left on port 7778 makes the suite test stale code):

```bash
pkill -f 'bin/zone' ; pkill -f 'bin/gateway' ; sleep 1
./run-integration.sh
```

Expected: `ALL TESTS OK` — `TestZoneChat` both cases green, and all prior server tests still pass.

- [ ] **Step 4: Run the shared + client suites for regression**

Run: `make test && ./build_native.sh client-test && ./bin/client-test`
Expected: both `ALL TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add client/src/headless/HeadlessClient.hx server/test/TestZoneChat.hx server/test/TestMain.hx
git commit -m "test(zone): two-client integration test for chat routing

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes

**Spec coverage:**
- §1 protocol (`MsgType.CHAT`, `ChatChannel`, `MsgChat`) → Task 1.
- §2 client (`ChatCommandParser` with `/g`, `/me`, canned emotes; `ChatBox` overlay; keyboard capture; send routing; both-dispatcher receive) → Tasks 2 and 5.
- §3 zone routing (`ChatHandler`, `InterestManager.observersOf`, sender + observers, server-filled `senderName`, 200-char cap) → Task 3.
- §4 gateway routing (`GatewayPlayers` registry, `LoginHandler` records, `GatewayChatHandler` broadcasts GLOBAL, drop if not logged in) → Task 4.
- §5 error handling (empty text ignored client-side in `onChatSubmit`; 200-char truncation in both handlers; unidentified-connection drop) and testing (shared round-trip, client parser unit, two-client integration) → Tasks 1, 2, 3, 4, 6.

**Placeholder scan:** none — every step has concrete code or an exact command.

**Type consistency:** `MsgChat` fields `channel:Int` / `senderName:String` / `text:String` are used identically in Tasks 1, 3, 4, 5, 6. `ChatCommandParser.parse` returns `{channel:Int, text:String}` (Task 2) and is consumed with those fields in `onChatSubmit` (Task 5). `ChatChannel` values `SAY`/`GLOBAL`/`EMOTE` are referenced consistently. `ChatHandler` constructor `(sim, enterHandler, interest)` matches its `Main.hx` call. `GatewayChatHandler` constructor `(players)` and `LoginHandler`'s new 4-arg constructor match their `Main.hx` calls. `HeadlessClient.sendChat(channel, text)` / `drainGatewayFrames(durationS)` match the test's usage. `drainFrames` (zone) is the pre-existing method, reused.

**Tick/stale-process note:** Task 6 Step 3 pre-kills stale `bin/zone`/`bin/gateway` — a lesson from the interest-management sub-project, where a leftover zone on port 7778 silently served stale code.

**Out of scope:** party chat, scrollback/tabs/colored styling, animated emotes, chat persistence.
