# M0 Foundation — Network Skeleton & Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the client/server/shared skeleton with a working end-to-end account-create + login flow over TCP, persisted to MySQL. Demo: launch server, launch client, log in with a created account, see "Welcome".

**Architecture:** Add `shared/`, `client/`, `server/`, alongside existing `src/` (haxecraft single-player game untouched). Shared Haxe protocol code (frame codec + `@:serializable` macro) compiled into both HL server and Heaps HL client. MySQL in Docker for dev, accessed via Haxe stdlib `sys.db.Mysql` (no external haxelib needed). Plain TCP for M0 (localhost-only); TLS layer goes on in M1 before any non-localhost use.

**Tech Stack:**
- Haxe 4.3.7, HashLink 1.16.0
- Heaps (existing), hlsdl, hlopenal
- MySQL 8 (Docker) via Haxe stdlib `sys.db.Mysql`
- utest for unit/integration tests
- Make for orchestration
- Password hashing: PBKDF2-SHA256 (Task 9 — Joshua approved this approach)

**Database choice note:** Originally specced as PostgreSQL. Switched to MySQL during planning when research turned up no maintained Postgres driver for HashLink. MySQL is in Haxe stdlib (`sys.db.Mysql`), zero external dependency. MySQL 8 `JSON` columns cover the JSONB use case for item properties. Spec updated to reflect this.

**M0 deliverable (definition of done):**
1. `make all` builds shared tests + server + client without error.
2. `make test` passes the full shared/proto unit test suite.
3. `docker-compose up -d mysql` brings a working DB up; migrations apply.
4. `./run-server.sh` brings up the server, prints `[server] listening on 127.0.0.1:7777`.
5. `./run-client.sh` opens a Heaps window, shows login screen, on submit successfully logs in and displays "Welcome, <username>".
6. Account creation via `./server-cli create-account <user> <pass>` works and the credentials authenticate against the running server.

**Out of scope for M0:** TLS, character creation/selection, zone simulation, world rendering, anything game-mechanical, anti-cheat hardening beyond intents-only architecture, headless client harness (M1).

**Worktree:** Implementation should happen in a dedicated worktree (existing `src/` has ~40 WIP modifications). Create with `git worktree add ../haxecraft-m0 -b feature/m0-foundation` before starting Task 1.

---

## File Structure

New top-level dirs (all created in Task 1):

```
haxecraft/
├── shared/                          NEW
│   ├── build-shared-test.hxml       run shared/ tests under HL
│   ├── src/
│   │   ├── shared/
│   │   │   ├── Constants.hx         PROTOCOL_VERSION, MAX_FRAME_SIZE, TICK_HZ
│   │   │   ├── proto/
│   │   │   │   ├── FrameCodec.hx    length-prefixed binary framing
│   │   │   │   ├── Serializable.hx  marker interface for @:build macro
│   │   │   │   ├── SerializableMacro.hx  compile-time codegen
│   │   │   │   ├── MsgType.hx       enum abstract: HELLO=1, HELLO_ACK=2, ...
│   │   │   │   ├── MsgHello.hx
│   │   │   │   ├── MsgHelloAck.hx
│   │   │   │   ├── MsgLogin.hx
│   │   │   │   ├── MsgLoginAck.hx
│   │   │   │   └── MsgError.hx
│   │   │   └── security/
│   │   │       └── PasswordHash.hx  hash + verify
│   └── test/                        utest cases
│       ├── TestFrameCodec.hx
│       ├── TestSerializableMacro.hx
│       ├── TestMessages.hx
│       └── TestMain.hx
├── server/                          NEW
│   ├── build-server.hxml
│   ├── build-server-cli.hxml
│   ├── src/
│   │   └── server/
│   │       ├── Main.hx              entry point: server mode
│   │       ├── ServerCliMain.hx     entry point: cli mode (create-account)
│   │       ├── net/
│   │       │   ├── TcpServer.hx     accept loop
│   │       │   ├── ClientConnection.hx  per-conn state + dispatch
│   │       │   └── MessageDispatcher.hx routes msgType → handler
│   │       ├── db/
│   │       │   ├── DbClient.hx      thin wrapper over sys.db.Mysql
│   │       │   └── AccountDal.hx    findByUsername, create
│   │       └── auth/
│   │           ├── LoginHandler.hx
│   │           └── HelloHandler.hx
│   └── test/
│       ├── TestDbClient.hx          requires running MySQL
│       ├── TestAccountDal.hx        requires running MySQL
│       ├── TestLoginFlow.hx         integration: synthetic client → real server
│       └── TestMain.hx
├── client/                          NEW
│   ├── build-client.hxml
│   ├── src/
│   │   └── client/
│   │       ├── Main.hx              hxd.App subclass, entry point
│   │       ├── net/
│   │       │   ├── TcpConnection.hx wraps sys.net.Socket for Heaps
│   │       │   └── ClientDispatcher.hx
│   │       └── ui/
│   │           ├── LoginScreen.hx
│   │           ├── ConnectingScreen.hx
│   │           └── WelcomeScreen.hx
├── db/                              NEW
│   └── migrations/
│       └── 0001_accounts.sql
├── docker-compose.yml               NEW
├── Makefile                         NEW
├── run-server.sh                    NEW
└── run-client.sh                    NEW
```

**Untouched in M0:** `src/`, `res/`, existing `build.hxml`, `build_macos.sh`, `run.sh`, `tools/`. The single-player haxecraft game continues to build via `build.hxml`.

---

## Task 1: Repo Skeleton + Top-Level Build Orchestration

**Files:**
- Create: `Makefile`
- Create: `shared/build-shared-test.hxml`
- Create: `shared/src/shared/.gitkeep`
- Create: `server/build-server.hxml`
- Create: `server/src/server/.gitkeep`
- Create: `client/build-client.hxml`
- Create: `client/src/client/.gitkeep`
- Create: `db/migrations/.gitkeep`

- [ ] **Step 1: Create directory skeleton**

```bash
mkdir -p shared/src/shared/proto shared/src/shared/security shared/test
mkdir -p server/src/server/net server/src/server/db server/src/server/auth server/test
mkdir -p client/src/client/net client/src/client/ui
mkdir -p db/migrations
touch shared/src/shared/.gitkeep server/src/server/.gitkeep client/src/client/.gitkeep db/migrations/.gitkeep
```

- [ ] **Step 2: Write `shared/build-shared-test.hxml`**

```
-cp src
-cp test
-lib utest
-main TestMain
--hl out/shared-test.hl
-D analyzer-optimize
```

- [ ] **Step 3: Write `server/build-server.hxml`**

```
-cp src
-cp ../shared/src
-lib utest
-main server.Main
--hl out/server.hl
-D analyzer-optimize
```

- [ ] **Step 4: Write `client/build-client.hxml`**

```
-cp src
-cp ../shared/src
-lib heaps
-lib hlsdl
-main client.Main
--hl out/client.hl
-D resourcesPath=../res
-D analyzer-optimize
```

- [ ] **Step 5: Write top-level `Makefile`**

```makefile
.PHONY: all shared-test server client test clean

SHARED_HXML := shared/build-shared-test.hxml
SERVER_HXML := server/build-server.hxml
CLIENT_HXML := client/build-client.hxml

all: shared-test server client

shared-test:
	cd shared && haxe build-shared-test.hxml

server:
	cd server && haxe build-server.hxml

client:
	cd client && haxe build-client.hxml

test: shared-test
	hl out/shared-test.hl

clean:
	rm -rf out/*.hl
```

- [ ] **Step 6: Install utest haxelib (if not present)**

```bash
haxelib install utest 2.0.2 || true
haxelib list | grep utest
```

Expected: `utest: [2.0.2]` (or similar).

- [ ] **Step 7: Write a stub `shared/test/TestMain.hx` so the build target is valid**

```haxe
class TestMain {
  public static function main() {
    Sys.println("shared tests: nothing yet");
  }
}
```

- [ ] **Step 8: Write stub `server/src/server/Main.hx`**

```haxe
package server;

class Main {
  public static function main() {
    Sys.println("[server] starting (stub)");
  }
}
```

- [ ] **Step 9: Write stub `client/src/client/Main.hx`**

```haxe
package client;

class Main extends hxd.App {
  static function main() {
    new Main();
  }
  override function init() {
    var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
    tf.text = "client stub";
  }
}
```

- [ ] **Step 10: Verify all three targets build**

```bash
make all
```

Expected: three `.hl` files in `out/`, no errors.

- [ ] **Step 11: Commit**

```bash
git add Makefile shared server client db
git commit -m "feat(m0): add shared/client/server skeleton + build orchestration"
```

---

## Task 2: Protocol Constants

**Files:**
- Create: `shared/src/shared/Constants.hx`
- Create: `shared/test/TestConstants.hx`

- [ ] **Step 1: Write failing test `shared/test/TestConstants.hx`**

```haxe
package;

import utest.Assert;
import utest.Test;
import shared.Constants;

class TestConstants extends Test {
  function testProtocolVersionIsPositive() {
    Assert.isTrue(Constants.PROTOCOL_VERSION > 0);
  }
  function testMaxFrameSizeIs64K() {
    Assert.equals(65535, Constants.MAX_FRAME_SIZE);
  }
  function testTickHz() {
    Assert.equals(10, Constants.TICK_HZ);
  }
  function testDefaultServerPort() {
    Assert.equals(7777, Constants.DEFAULT_SERVER_PORT);
  }
}
```

- [ ] **Step 2: Update `shared/test/TestMain.hx` to run TestConstants**

```haxe
package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestConstants());
    Report.create(r);
    r.run();
  }
}
```

- [ ] **Step 3: Run test, verify failure (Constants module missing)**

```bash
make test
```

Expected: build error referencing `shared.Constants`.

- [ ] **Step 4: Create `shared/src/shared/Constants.hx`**

```haxe
package shared;

class Constants {
  public static inline var PROTOCOL_VERSION:Int = 1;
  public static inline var MAX_FRAME_SIZE:Int = 65535;
  public static inline var TICK_HZ:Int = 10;
  public static inline var DEFAULT_SERVER_PORT:Int = 7777;
  public static inline var DEFAULT_SERVER_HOST:String = "127.0.0.1";
}
```

- [ ] **Step 5: Run tests, verify pass**

```bash
make test
```

Expected: all 4 assertions pass.

- [ ] **Step 6: Commit**

```bash
git add shared/src/shared/Constants.hx shared/test/TestConstants.hx shared/test/TestMain.hx
git commit -m "feat(m0): add shared protocol constants"
```

---

## Task 3: Frame Codec — Writer

A frame is `[u16 length][u8 msgType][payload bytes]`. Length excludes itself (covers msgType + payload). Hard cap MAX_FRAME_SIZE.

**Files:**
- Create: `shared/src/shared/proto/FrameCodec.hx`
- Create: `shared/test/TestFrameCodec.hx`

- [ ] **Step 1: Write failing test for `FrameCodec.writeFrame`**

```haxe
package;

import utest.Assert;
import utest.Test;
import haxe.io.BytesOutput;
import haxe.io.Bytes;
import shared.proto.FrameCodec;

class TestFrameCodec extends Test {
  function testWriteFrameEmptyPayload() {
    var out = new BytesOutput();
    var payload = Bytes.alloc(0);
    FrameCodec.writeFrame(out, 42, payload);
    var result = out.getBytes();
    // length=1 (just msgType byte), msgType=42, no payload
    Assert.equals(3, result.length);
    Assert.equals(1, result.getUInt16(0));   // length (LE)
    Assert.equals(42, result.get(2));         // msgType
  }

  function testWriteFrameWithPayload() {
    var out = new BytesOutput();
    var payload = Bytes.ofString("hi");
    FrameCodec.writeFrame(out, 7, payload);
    var result = out.getBytes();
    Assert.equals(5, result.length);
    Assert.equals(3, result.getUInt16(0));   // 1 (msgType) + 2 (payload)
    Assert.equals(7, result.get(2));
    Assert.equals(0x68, result.get(3));      // 'h'
    Assert.equals(0x69, result.get(4));      // 'i'
  }

  function testWriteFrameRejectsOversizedPayload() {
    var out = new BytesOutput();
    var payload = Bytes.alloc(70000);
    Assert.raises(() -> FrameCodec.writeFrame(out, 1, payload));
  }
}
```

- [ ] **Step 2: Register TestFrameCodec in TestMain**

Edit `shared/test/TestMain.hx`, after `r.addCase(new TestConstants());` add:

```haxe
    r.addCase(new TestFrameCodec());
```

- [ ] **Step 3: Run, verify failure**

```bash
make test
```

Expected: `FrameCodec` not found.

- [ ] **Step 4: Implement `shared/src/shared/proto/FrameCodec.hx` (writer only for now)**

```haxe
package shared.proto;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Input;
import shared.Constants;

class FrameCodec {
  public static function writeFrame(out:BytesOutput, msgType:Int, payload:Bytes):Void {
    var len = payload.length + 1;
    if (len > Constants.MAX_FRAME_SIZE) {
      throw "frame too large: " + len + " bytes (max " + Constants.MAX_FRAME_SIZE + ")";
    }
    out.writeUInt16(len);
    out.writeByte(msgType);
    if (payload.length > 0) out.writeBytes(payload, 0, payload.length);
  }
}
```

Note: `writeUInt16` is little-endian by default in Haxe `BytesOutput`. That's our wire format. Document this on the class once we add docs.

- [ ] **Step 5: Run, verify pass**

```bash
make test
```

Expected: all FrameCodec writer tests pass.

- [ ] **Step 6: Commit**

```bash
git add shared/src/shared/proto/FrameCodec.hx shared/test/TestFrameCodec.hx shared/test/TestMain.hx
git commit -m "feat(m0): FrameCodec.writeFrame with size cap"
```

---

## Task 4: Frame Codec — Reader

Reading is harder than writing because TCP gives us streams, not packets. We need partial-read tolerance.

**Files:**
- Modify: `shared/src/shared/proto/FrameCodec.hx`
- Modify: `shared/test/TestFrameCodec.hx`

- [ ] **Step 1: Append failing tests for `readFrame`**

Add to `TestFrameCodec.hx`:

```haxe
  function testReadFrameRoundtrip() {
    var out = new BytesOutput();
    var payload = Bytes.ofString("hello");
    FrameCodec.writeFrame(out, 3, payload);
    var inp = new haxe.io.BytesInput(out.getBytes());
    var frame = FrameCodec.readFrame(inp);
    Assert.equals(3, frame.msgType);
    Assert.equals("hello", frame.payload.toString());
  }

  function testReadFrameRejectsOversizedHeader() {
    var b = Bytes.alloc(3);
    b.setUInt16(0, 70000);  // claimed length, exceeds MAX_FRAME_SIZE
    b.set(2, 1);
    var inp = new haxe.io.BytesInput(b);
    Assert.raises(() -> FrameCodec.readFrame(inp));
  }
```

- [ ] **Step 2: Run, verify failure**

```bash
make test
```

Expected: `readFrame` undefined.

- [ ] **Step 3: Add `readFrame` to FrameCodec**

Append inside `FrameCodec` class:

```haxe
  public static function readFrame(inp:Input):{msgType:Int, payload:Bytes} {
    var len = inp.readUInt16();
    if (len < 1 || len > Constants.MAX_FRAME_SIZE) {
      throw "invalid frame length: " + len;
    }
    var msgType = inp.readByte();
    var payloadLen = len - 1;
    var payload = payloadLen > 0 ? inp.read(payloadLen) : Bytes.alloc(0);
    return { msgType: msgType, payload: payload };
  }
```

Note: `inp.read(n)` blocks until `n` bytes available. The server-side socket reader (Task 16) handles non-blocking reads at the socket layer and only calls `readFrame` once a full frame is buffered.

- [ ] **Step 4: Run, verify pass**

```bash
make test
```

- [ ] **Step 5: Commit**

```bash
git add shared/src/shared/proto/FrameCodec.hx shared/test/TestFrameCodec.hx
git commit -m "feat(m0): FrameCodec.readFrame"
```

---

## Task 5: Message Type Enum

A single source of truth for `msgType` byte values, shared across client and server.

**Files:**
- Create: `shared/src/shared/proto/MsgType.hx`
- Create: `shared/test/TestMsgType.hx`

- [ ] **Step 1: Write failing test**

```haxe
package;

import utest.Assert;
import utest.Test;
import shared.proto.MsgType;

class TestMsgType extends Test {
  function testValuesAreStableAndUnique() {
    Assert.equals(1, (MsgType.HELLO : Int));
    Assert.equals(2, (MsgType.HELLO_ACK : Int));
    Assert.equals(3, (MsgType.LOGIN : Int));
    Assert.equals(4, (MsgType.LOGIN_ACK : Int));
    Assert.equals(5, (MsgType.ERROR : Int));
  }
}
```

Add `r.addCase(new TestMsgType());` to TestMain.

- [ ] **Step 2: Run, verify failure**

```bash
make test
```

- [ ] **Step 3: Implement `shared/src/shared/proto/MsgType.hx`**

```haxe
package shared.proto;

enum abstract MsgType(Int) to Int from Int {
  var HELLO = 1;
  var HELLO_ACK = 2;
  var LOGIN = 3;
  var LOGIN_ACK = 4;
  var ERROR = 5;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
make test
```

- [ ] **Step 5: Commit**

```bash
git add shared/src/shared/proto/MsgType.hx shared/test/TestMsgType.hx shared/test/TestMain.hx
git commit -m "feat(m0): MsgType enum abstract"
```

---

## Task 6: @:serializable Macro — Int/String/Bool Support

This is the protocol-class codegen macro. Each `@:build(SerializableMacro.build())` class gets `serialize(out:BytesOutput)` and static `deserialize(inp:Input)` methods generated from its `public var` fields.

Supported field types for M0: `Int` (i32 LE), `String` (length-prefixed u16 + UTF-8 bytes), `Bool` (1 byte). Adding more types is a single-file edit later.

**Files:**
- Create: `shared/src/shared/proto/Serializable.hx`
- Create: `shared/src/shared/proto/SerializableMacro.hx`
- Create: `shared/test/TestSerializableMacro.hx`
- Create: `shared/test/_fixtures/TestMsg.hx` (used only by the macro test)

- [ ] **Step 1: Create the marker interface**

`shared/src/shared/proto/Serializable.hx`:

```haxe
package shared.proto;

interface Serializable {}
```

- [ ] **Step 2: Create the test fixture class that USES the macro**

`shared/test/_fixtures/TestMsg.hx`:

```haxe
package _fixtures;

@:build(shared.proto.SerializableMacro.build())
class TestMsg implements shared.proto.Serializable {
  public var i:Int = 0;
  public var s:String = "";
  public var b:Bool = false;
  public function new() {}
}
```

- [ ] **Step 3: Add test fixture path to build-shared-test.hxml**

Edit `shared/build-shared-test.hxml`, replace the existing `-cp test` line with:

```
-cp test
-cp test/_fixtures
```

- [ ] **Step 4: Write failing round-trip test**

`shared/test/TestSerializableMacro.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import haxe.io.BytesOutput;
import haxe.io.BytesInput;
import _fixtures.TestMsg;

class TestSerializableMacro extends Test {
  function testRoundTrip() {
    var m = new TestMsg();
    m.i = 12345;
    m.s = "hello world";
    m.b = true;

    var out = new BytesOutput();
    m.serialize(out);
    var inp = new BytesInput(out.getBytes());
    var m2 = TestMsg.deserialize(inp);

    Assert.equals(12345, m2.i);
    Assert.equals("hello world", m2.s);
    Assert.isTrue(m2.b);
  }

  function testEmptyString() {
    var m = new TestMsg();
    m.s = "";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = TestMsg.deserialize(new BytesInput(out.getBytes()));
    Assert.equals("", m2.s);
  }

  function testFalseBool() {
    var m = new TestMsg();
    m.b = false;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = TestMsg.deserialize(new BytesInput(out.getBytes()));
    Assert.isFalse(m2.b);
  }
}
```

Add `r.addCase(new TestSerializableMacro());` to TestMain.

- [ ] **Step 5: Run, verify failure (SerializableMacro undefined)**

```bash
make test
```

- [ ] **Step 6: Implement the macro**

`shared/src/shared/proto/SerializableMacro.hx`:

```haxe
package shared.proto;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ComplexTypeTools;

class SerializableMacro {
  public static function build():Array<Field> {
    var fields = Context.getBuildFields();
    var pos = Context.currentPos();

    var writeExprs:Array<Expr> = [];
    var readExprs:Array<Expr> = [];

    for (f in fields) {
      switch f.kind {
        case FVar(t, _):
          if (t == null) continue;
          var fname = f.name;
          var typeStr = ComplexTypeTools.toString(t);
          switch typeStr {
            case "Int":
              writeExprs.push(macro out.writeInt32(this.$fname));
              readExprs.push(macro inst.$fname = inp.readInt32());
            case "String":
              writeExprs.push(macro {
                var __bytes = haxe.io.Bytes.ofString(this.$fname);
                out.writeUInt16(__bytes.length);
                if (__bytes.length > 0) out.writeBytes(__bytes, 0, __bytes.length);
              });
              readExprs.push(macro {
                var __len = inp.readUInt16();
                inst.$fname = __len > 0 ? inp.read(__len).toString() : "";
              });
            case "Bool":
              writeExprs.push(macro out.writeByte(this.$fname ? 1 : 0));
              readExprs.push(macro inst.$fname = inp.readByte() != 0);
            default:
              Context.error("SerializableMacro: unsupported type '" + typeStr +
                "' on field '" + fname + "' (supported: Int, String, Bool)", f.pos);
          }
        default:
          // skip non-var fields (methods, properties)
      }
    }

    var clsName = Context.getLocalClass().get().name;
    var clsPath = Context.getLocalClass().toString().split(".");
    var clsTypePath:TypePath = { pack: clsPath.slice(0, -1), name: clsName };

    fields.push({
      name: "serialize",
      pos: pos,
      access: [APublic],
      kind: FFun({
        args: [{ name: "out", type: macro:haxe.io.BytesOutput }],
        ret: macro:Void,
        expr: macro $b{writeExprs}
      })
    });

    fields.push({
      name: "deserialize",
      pos: pos,
      access: [APublic, AStatic],
      kind: FFun({
        args: [{ name: "inp", type: macro:haxe.io.Input }],
        ret: TPath(clsTypePath),
        expr: macro {
          var inst = new $clsTypePath();
          $b{readExprs};
          return inst;
        }
      })
    });

    return fields;
  }
}
#end
```

- [ ] **Step 7: Run, verify pass**

```bash
make test
```

Expected: all three TestSerializableMacro tests pass.

- [ ] **Step 8: Commit**

```bash
git add shared/src/shared/proto/Serializable.hx shared/src/shared/proto/SerializableMacro.hx \
        shared/test/TestSerializableMacro.hx shared/test/_fixtures/TestMsg.hx \
        shared/build-shared-test.hxml shared/test/TestMain.hx
git commit -m "feat(m0): @:serializable build macro (Int/String/Bool)"
```

---

## Task 7: Protocol Message Classes

The five M0 messages. Each gets the macro treatment.

**Files:**
- Create: `shared/src/shared/proto/MsgHello.hx`
- Create: `shared/src/shared/proto/MsgHelloAck.hx`
- Create: `shared/src/shared/proto/MsgLogin.hx`
- Create: `shared/src/shared/proto/MsgLoginAck.hx`
- Create: `shared/src/shared/proto/MsgError.hx`
- Create: `shared/test/TestMessages.hx`

- [ ] **Step 1: Write failing test for all five message classes**

```haxe
package;

import utest.Assert;
import utest.Test;
import haxe.io.BytesOutput;
import haxe.io.BytesInput;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgError;

class TestMessages extends Test {
  function testHello() {
    var m = new MsgHello();
    m.protocolVersion = 1;
    m.buildHash = "deadbeef";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgHello.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(1, m2.protocolVersion);
    Assert.equals("deadbeef", m2.buildHash);
  }

  function testHelloAck() {
    var m = new MsgHelloAck();
    m.ok = true;
    m.reason = "";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgHelloAck.deserialize(new BytesInput(out.getBytes()));
    Assert.isTrue(m2.ok);
    Assert.equals("", m2.reason);
  }

  function testLogin() {
    var m = new MsgLogin();
    m.username = "joshua";
    m.password = "pw";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgLogin.deserialize(new BytesInput(out.getBytes()));
    Assert.equals("joshua", m2.username);
    Assert.equals("pw", m2.password);
  }

  function testLoginAck() {
    var m = new MsgLoginAck();
    m.success = true;
    m.sessionToken = "tok-123";
    m.errorMsg = "";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgLoginAck.deserialize(new BytesInput(out.getBytes()));
    Assert.isTrue(m2.success);
    Assert.equals("tok-123", m2.sessionToken);
  }

  function testError() {
    var m = new MsgError();
    m.code = 42;
    m.message = "bad client";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = MsgError.deserialize(new BytesInput(out.getBytes()));
    Assert.equals(42, m2.code);
    Assert.equals("bad client", m2.message);
  }
}
```

Register in TestMain.

- [ ] **Step 2: Run, verify all five fail (classes missing)**

```bash
make test
```

- [ ] **Step 3: Create `MsgHello.hx`**

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgHello implements Serializable {
  public var protocolVersion:Int = 0;
  public var buildHash:String = "";
  public function new() {}
}
```

- [ ] **Step 4: Create `MsgHelloAck.hx`**

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgHelloAck implements Serializable {
  public var ok:Bool = false;
  public var reason:String = "";
  public function new() {}
}
```

- [ ] **Step 5: Create `MsgLogin.hx`**

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgLogin implements Serializable {
  public var username:String = "";
  public var password:String = "";
  public function new() {}
}
```

- [ ] **Step 6: Create `MsgLoginAck.hx`**

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgLoginAck implements Serializable {
  public var success:Bool = false;
  public var sessionToken:String = "";
  public var errorMsg:String = "";
  public function new() {}
}
```

- [ ] **Step 7: Create `MsgError.hx`**

```haxe
package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgError implements Serializable {
  public var code:Int = 0;
  public var message:String = "";
  public function new() {}
}
```

- [ ] **Step 8: Run, verify all pass**

```bash
make test
```

- [ ] **Step 9: Commit**

```bash
git add shared/src/shared/proto/Msg*.hx shared/test/TestMessages.hx shared/test/TestMain.hx
git commit -m "feat(m0): protocol message classes (Hello/HelloAck/Login/LoginAck/Error)"
```

---

## Task 8: MySQL Docker Setup + Initial Migration

**Files:**
- Create: `docker-compose.yml`
- Create: `db/migrations/0001_accounts.sql`
- Create: `db/apply-migrations.sh`

- [ ] **Step 1: Write `docker-compose.yml`**

```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: haxecraft-mysql
    environment:
      MYSQL_ROOT_PASSWORD: dev_root_only
      MYSQL_USER: haxecraft
      MYSQL_PASSWORD: dev_local_only
      MYSQL_DATABASE: haxecraft
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    ports:
      - "3306:3306"
    volumes:
      - haxecraft-mysqldata:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-uhaxecraft", "-pdev_local_only", "--silent"]
      interval: 5s
      timeout: 3s
      retries: 20

volumes:
  haxecraft-mysqldata:
```

- [ ] **Step 2: Write `db/migrations/0001_accounts.sql`**

```sql
CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    banned_until TIMESTAMP NULL,
    INDEX idx_accounts_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Note: `UNIQUE` constraint on `username` already creates an implicit index; the explicit `INDEX idx_accounts_username` is harmless redundancy that documents intent.

- [ ] **Step 3: Write `db/apply-migrations.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
for f in "$HERE"/migrations/*.sql; do
  echo "applying $(basename "$f")"
  docker exec -i haxecraft-mysql mysql -uhaxecraft -pdev_local_only haxecraft < "$f"
done
```

(Using `docker exec` keeps us from requiring a local `mysql` client install.)

- [ ] **Step 4: Make script executable + bring MySQL up + apply migrations**

```bash
chmod +x db/apply-migrations.sh
docker-compose up -d mysql
# wait for healthy (MySQL 8 first-boot is slow; allow up to 60s)
for i in {1..60}; do
  if docker inspect haxecraft-mysql 2>/dev/null | grep -q '"Status": "healthy"'; then
    break
  fi
  sleep 1
done
./db/apply-migrations.sh
```

Expected: prints `applying 0001_accounts.sql`, exits 0. (Suppress the standard MySQL "Using a password on the command line is insecure" warning — it's fine for dev.)

- [ ] **Step 5: Verify schema**

```bash
docker exec -i haxecraft-mysql mysql -uhaxecraft -pdev_local_only haxecraft -e "DESCRIBE accounts;"
```

Expected: 6 columns listed (id, username, password_hash, created_at, last_login, banned_until).

- [ ] **Step 6: Commit**

```bash
git add docker-compose.yml db/
git commit -m "feat(m0): mysql docker + accounts schema migration"
```

---

## Task 9: Password Hashing — Library Research + Integration

**Research outcome:** Pick one of:
- **(preferred)** `haxelib` package providing bcrypt or argon2 with HL support
- PBKDF2 implementation via `haxe.crypto.Hmac` + `haxe.crypto.Sha256` (pure Haxe, works on all targets)

**Files:**
- Create: `shared/src/shared/security/PasswordHash.hx`
- Create: `shared/test/TestPasswordHash.hx`

- [ ] **Step 1: Search haxelib for bcrypt/argon2**

```bash
haxelib search bcrypt
haxelib search argon2
```

Pick the best supported option that works on HL. If none works on HL, fall back to the PBKDF2 approach (haxe.crypto is in the Haxe stdlib).

**Decision rule:** prefer a maintained library. If the most-recently-updated option is >2 years stale or doesn't list HL as a target, fall back to PBKDF2-SHA256 (100,000 iterations, 16-byte salt). Document choice in a comment at top of `PasswordHash.hx`.

- [ ] **Step 2: Write failing test**

```haxe
package;

import utest.Assert;
import utest.Test;
import shared.security.PasswordHash;

class TestPasswordHash extends Test {
  function testHashIsNotPlaintext() {
    var h = PasswordHash.hash("hunter2");
    Assert.notEquals("hunter2", h);
    Assert.isTrue(h.length > 20);
  }

  function testCorrectPasswordVerifies() {
    var h = PasswordHash.hash("hunter2");
    Assert.isTrue(PasswordHash.verify("hunter2", h));
  }

  function testWrongPasswordRejected() {
    var h = PasswordHash.hash("hunter2");
    Assert.isFalse(PasswordHash.verify("Hunter2", h));
    Assert.isFalse(PasswordHash.verify("", h));
    Assert.isFalse(PasswordHash.verify("hunter22", h));
  }

  function testTwoHashesOfSamePasswordDiffer() {
    var h1 = PasswordHash.hash("hunter2");
    var h2 = PasswordHash.hash("hunter2");
    Assert.notEquals(h1, h2);  // salts differ
    Assert.isTrue(PasswordHash.verify("hunter2", h1));
    Assert.isTrue(PasswordHash.verify("hunter2", h2));
  }
}
```

Register in TestMain.

- [ ] **Step 3: Implement PBKDF2 fallback** (use this if no good lib found in Step 1; otherwise adapt to chosen lib)

```haxe
package shared.security;

// PBKDF2-SHA256, 100k iterations, 16-byte salt. Format: "pbkdf2$<iters>$<salt_hex>$<hash_hex>".
// Replace with bcrypt/argon2 if/when a maintained HL-compatible lib lands.

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.crypto.Hmac;

class PasswordHash {
  static inline var ITERATIONS = 100000;
  static inline var SALT_LEN = 16;
  static inline var KEY_LEN = 32;

  public static function hash(password:String):String {
    var salt = randomBytes(SALT_LEN);
    var key = pbkdf2Sha256(Bytes.ofString(password), salt, ITERATIONS, KEY_LEN);
    return 'pbkdf2\$$ITERATIONS\$${salt.toHex()}\$${key.toHex()}';
  }

  public static function verify(password:String, stored:String):Bool {
    var parts = stored.split("$");
    if (parts.length != 4 || parts[0] != "pbkdf2") return false;
    var iters = Std.parseInt(parts[1]);
    if (iters == null) return false;
    var salt = Bytes.ofHex(parts[2]);
    var expected = Bytes.ofHex(parts[3]);
    var actual = pbkdf2Sha256(Bytes.ofString(password), salt, iters, expected.length);
    return constantTimeEquals(expected, actual);
  }

  static function randomBytes(n:Int):Bytes {
    var b = Bytes.alloc(n);
    for (i in 0...n) b.set(i, Std.random(256));
    return b;
  }

  static function constantTimeEquals(a:Bytes, b:Bytes):Bool {
    if (a.length != b.length) return false;
    var diff = 0;
    for (i in 0...a.length) diff |= a.get(i) ^ b.get(i);
    return diff == 0;
  }

  static function pbkdf2Sha256(password:Bytes, salt:Bytes, iters:Int, keyLen:Int):Bytes {
    var hmac = new Hmac(SHA256);
    var blocks = Math.ceil(keyLen / 32);
    var out = Bytes.alloc(blocks * 32);
    for (i in 1...blocks + 1) {
      var saltBlock = Bytes.alloc(salt.length + 4);
      saltBlock.blit(0, salt, 0, salt.length);
      saltBlock.set(salt.length, (i >> 24) & 0xff);
      saltBlock.set(salt.length + 1, (i >> 16) & 0xff);
      saltBlock.set(salt.length + 2, (i >> 8) & 0xff);
      saltBlock.set(salt.length + 3, i & 0xff);
      var u = hmac.make(password, saltBlock);
      var t = u.sub(0, u.length);
      for (_ in 1...iters) {
        u = hmac.make(password, u);
        for (j in 0...t.length) t.set(j, t.get(j) ^ u.get(j));
      }
      out.blit((i - 1) * 32, t, 0, 32);
    }
    return out.sub(0, keyLen);
  }
}
```

Note: `Std.random` is not cryptographically secure. For M0/localhost-only this is acceptable; flag for replacement before launch with hl-native crypto-RNG or libsodium binding.

- [ ] **Step 4: Run, verify tests pass**

```bash
make test
```

- [ ] **Step 5: Commit**

```bash
git add shared/src/shared/security/PasswordHash.hx shared/test/TestPasswordHash.hx shared/test/TestMain.hx
git commit -m "feat(m0): PBKDF2-SHA256 password hashing (M0; replace with libsodium pre-launch)"
```

---

## Task 10: DbClient — Thin Wrapper Over sys.db.Mysql

The Haxe stdlib provides `sys.db.Mysql` for HashLink — no external haxelib required. The stdlib `Connection` interface is raw (single `request(sql)` method, manual escape/quote/addValue helpers), so we build a small `?`-placeholder helper on top for safety and ergonomics.

**Files:**
- Create: `server/src/server/db/DbClient.hx`
- Create: `server/test/TestDbClient.hx`
- Create: `server/build-server-test.hxml`
- Create: `server/test/TestMain.hx`
- Modify: `Makefile`

- [ ] **Step 1: Write `server/src/server/db/DbClient.hx`**

```haxe
package server.db;

import sys.db.Mysql;
import sys.db.Connection;

// Thin wrapper over Haxe stdlib sys.db.Mysql. Single connection per process for M0.
// Connection pooling deferred to M1 (when multiple zones each open their own connection
// is still fine; pooling matters once a single process needs concurrent queries).
//
// Placeholder convention: `?` in SQL is replaced by the next param value, properly escaped
// via cnx.addValue(). Caller must NOT use `?` inside string literals — for our internal
// queries this constraint holds.

class DbClient {
  var cnx:Connection;

  public function new(host:String, port:Int, db:String, user:String, password:String) {
    cnx = Mysql.connect({
      host: host,
      port: port,
      user: user,
      pass: password,
      database: db,
      socket: null
    });
  }

  /** Run a SELECT-style query. Returns rows as Array<Dynamic> with column-name fields. */
  public function query(sql:String, params:Array<Dynamic>):Array<Dynamic> {
    var rs = cnx.request(bindParams(sql, params));
    var rows = new Array<Dynamic>();
    for (r in rs) rows.push(r);
    return rows;
  }

  /** Run a mutation (INSERT/UPDATE/DELETE). Returns affected-row count via ResultSet.length. */
  public function exec(sql:String, params:Array<Dynamic>):Int {
    var rs = cnx.request(bindParams(sql, params));
    return rs.length;
  }

  /** Returns the auto-increment id of the last INSERT on this connection. */
  public function lastInsertId():Int {
    return cnx.lastInsertId();
  }

  public function close():Void {
    cnx.close();
  }

  function bindParams(sql:String, params:Array<Dynamic>):String {
    if (params.length == 0) return sql;
    var sb = new StringBuf();
    var pi = 0;
    for (i in 0...sql.length) {
      var ch = sql.charAt(i);
      if (ch == "?") {
        if (pi >= params.length) throw "DbClient: too few params for placeholders in: " + sql;
        cnx.addValue(sb, params[pi++]);
      } else {
        sb.add(ch);
      }
    }
    if (pi != params.length) throw "DbClient: too many params (" + params.length + ") for placeholders in: " + sql;
    return sb.toString();
  }
}
```

- [ ] **Step 2: Write failing integration test `server/test/TestDbClient.hx`**

```haxe
package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;

class TestDbClient extends Test {
  var db:DbClient;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
  }

  function teardownClass() {
    if (db != null) db.close();
  }

  function testTrivialQuery() {
    var rows = db.query("SELECT 1 AS one", []);
    Assert.equals(1, rows.length);
    Assert.equals(1, rows[0].one);
  }

  function testParameterizedQueryEscapesSafely() {
    var rows = db.query("SELECT ? AS s", ["it's fine"]);
    Assert.equals(1, rows.length);
    Assert.equals("it's fine", rows[0].s);
  }

  function testAccountsTableExists() {
    var rows = db.query(
      "SELECT column_name FROM information_schema.columns WHERE table_schema = 'haxecraft' AND table_name = 'accounts' ORDER BY ordinal_position",
      []
    );
    Assert.equals(6, rows.length);
  }

  function testTooFewParamsThrows() {
    Assert.raises(() -> db.query("SELECT ? AS x", []));
  }

  function testTooManyParamsThrows() {
    Assert.raises(() -> db.query("SELECT 1", [42]));
  }
}
```

- [ ] **Step 3: Write `server/test/TestMain.hx`**

```haxe
package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestDbClient());
    Report.create(r);
    r.run();
  }
}
```

- [ ] **Step 4: Write `server/build-server-test.hxml`**

```
-cp src
-cp test
-cp ../shared/src
-lib utest
-main TestMain
--hl out/server-test.hl
```

(No `-lib mysql` — `sys.db.Mysql` is in Haxe stdlib for HashLink.)

- [ ] **Step 5: Append server-test target to Makefile**

```makefile
server-test:
	cd server && haxe build-server-test.hxml
	hl out/server-test.hl
```

- [ ] **Step 6: Run server test, verify pass against running MySQL**

```bash
docker-compose up -d mysql && sleep 5 && ./db/apply-migrations.sh
make server-test
```

Expected: 5 tests pass.

- [ ] **Step 7: Commit**

```bash
git add server/src/server/db/DbClient.hx server/test/TestDbClient.hx \
        server/test/TestMain.hx server/build-server-test.hxml Makefile
git commit -m "feat(m0): DbClient over sys.db.Mysql with ? placeholder binding"
```

---

## Task 11: Account DAL

**Files:**
- Create: `server/src/server/db/AccountDal.hx`
- Create: `server/test/TestAccountDal.hx`

- [ ] **Step 1: Write failing test**

```haxe
package;

import utest.Assert;
import utest.Test;
import server.db.DbClient;
import server.db.AccountDal;

class TestAccountDal extends Test {
  var db:DbClient;
  var dal:AccountDal;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    dal = new AccountDal(db);
    db.exec("DELETE FROM accounts WHERE username LIKE 'test\\_%'", []);
  }

  function teardownClass() {
    if (db != null) {
      db.exec("DELETE FROM accounts WHERE username LIKE 'test\\_%'", []);
      db.close();
    }
  }

  function testCreateAndFind() {
    var id = dal.create("test_alice", "hash_abc");
    Assert.isTrue(id > 0);
    var acct = dal.findByUsername("test_alice");
    Assert.notNull(acct);
    Assert.equals("test_alice", acct.username);
    Assert.equals("hash_abc", acct.passwordHash);
  }

  function testFindMissingReturnsNull() {
    Assert.isNull(dal.findByUsername("test_no_such_user"));
  }

  function testDuplicateUsernameRejected() {
    dal.create("test_bob", "x");
    Assert.raises(() -> dal.create("test_bob", "y"));
  }
}
```

Note: the `\\_` escape in the cleanup `DELETE` prevents MySQL from treating `_` as a single-char wildcard. We want a literal underscore so we only delete `test_*` rows, not arbitrary 5-letter names starting with "test".

Register in `server/test/TestMain.hx` (add `r.addCase(new TestAccountDal());` to TestMain after the TestDbClient line).

- [ ] **Step 2: Run, verify failure (AccountDal missing)**

```bash
make server-test
```

- [ ] **Step 3: Implement `server/src/server/db/AccountDal.hx`**

```haxe
package server.db;

typedef Account = {
  id:Int,
  username:String,
  passwordHash:String
};

class AccountDal {
  var db:DbClient;

  public function new(db:DbClient) {
    this.db = db;
  }

  public function findByUsername(username:String):Null<Account> {
    var rows = db.query(
      "SELECT id, username, password_hash FROM accounts WHERE username = ? LIMIT 1",
      [username]
    );
    if (rows.length == 0) return null;
    var r = rows[0];
    return { id: r.id, username: r.username, passwordHash: r.password_hash };
  }

  public function create(username:String, passwordHash:String):Int {
    db.exec(
      "INSERT INTO accounts (username, password_hash) VALUES (?, ?)",
      [username, passwordHash]
    );
    return db.lastInsertId();
  }
}
```

Note: MySQL doesn't support `INSERT ... RETURNING` (it's Postgres-specific). We use `lastInsertId()` on the same connection right after the INSERT — safe because each process holds a single connection in M0.

- [ ] **Step 4: Run, verify pass**

```bash
make server-test
```

- [ ] **Step 5: Commit**

```bash
git add server/src/server/db/AccountDal.hx server/test/TestAccountDal.hx server/test/TestMain.hx
git commit -m "feat(m0): AccountDal (findByUsername, create)"
```

---

## Task 12: Server CLI — create-account Command

A small CLI binary for ops use. Lets us seed accounts without a registration UI.

**Files:**
- Create: `server/src/server/ServerCliMain.hx`
- Create: `server/build-server-cli.hxml`
- Modify: `Makefile` (add `server-cli` target)

- [ ] **Step 1: Write `server/build-server-cli.hxml`**

```
-cp src
-cp ../shared/src
-main server.ServerCliMain
--hl out/server-cli.hl
```

(No `-lib mysql` — `sys.db.Mysql` is in Haxe stdlib for HashLink.)

- [ ] **Step 2: Append to Makefile**

```makefile
server-cli:
	cd server && haxe build-server-cli.hxml
```

Also update the top-level `all:` rule to include `server-cli`:

```makefile
all: shared-test server server-cli client
```

- [ ] **Step 3: Implement `ServerCliMain.hx`**

```haxe
package server;

import server.db.DbClient;
import server.db.AccountDal;
import shared.security.PasswordHash;

class ServerCliMain {
  public static function main() {
    var args = Sys.args();
    if (args.length < 1) { usage(); Sys.exit(1); }

    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var dal = new AccountDal(db);

    switch args[0] {
      case "create-account":
        if (args.length != 3) { usage(); Sys.exit(1); }
        var username = args[1];
        var password = args[2];
        if (dal.findByUsername(username) != null) {
          Sys.println('error: account "$username" already exists');
          Sys.exit(2);
        }
        var hash = PasswordHash.hash(password);
        var id = dal.create(username, hash);
        Sys.println('created account id=$id username=$username');
      default:
        usage();
        Sys.exit(1);
    }
    db.close();
  }

  static function usage() {
    Sys.println("usage: server-cli create-account <username> <password>");
  }
}
```

- [ ] **Step 4: Build and exercise**

```bash
make server-cli
hl out/server-cli.hl create-account testuser1 testpass1
```

Expected: `created account id=1 username=testuser1`.

- [ ] **Step 5: Verify in DB**

```bash
PGPASSWORD=dev_local_only psql -h 127.0.0.1 -U haxecraft -d haxecraft -c "SELECT id, username FROM accounts;"
```

Expected: row with `testuser1`.

- [ ] **Step 6: Commit**

```bash
git add server/src/server/ServerCliMain.hx server/build-server-cli.hxml Makefile
git commit -m "feat(m0): server-cli create-account command"
```

---

## Task 13: TCP Server Skeleton + Accept Loop

**Files:**
- Create: `server/src/server/net/TcpServer.hx`
- Create: `server/src/server/net/ClientConnection.hx`

- [ ] **Step 1: Implement `ClientConnection.hx` (stub for accept loop to use)**

```haxe
package server.net;

import sys.net.Socket;

class ClientConnection {
  public var socket:Socket;
  public var id:Int;

  public function new(socket:Socket, id:Int) {
    this.socket = socket;
    this.id = id;
  }

  public function close():Void {
    try socket.close() catch (_:Dynamic) {}
  }
}
```

- [ ] **Step 2: Implement `TcpServer.hx`**

```haxe
package server.net;

import sys.net.Socket;
import sys.net.Host;

class TcpServer {
  var listenSocket:Socket;
  var nextConnId:Int = 1;
  public var connections:Array<ClientConnection> = [];

  public function new(host:String, port:Int) {
    listenSocket = new Socket();
    listenSocket.bind(new Host(host), port);
    listenSocket.listen(32);
    listenSocket.setBlocking(false);
    Sys.println('[server] listening on $host:$port');
  }

  /** Non-blocking accept. Returns new connections accepted this tick. */
  public function tickAccept():Array<ClientConnection> {
    var fresh:Array<ClientConnection> = [];
    while (true) {
      try {
        var s = listenSocket.accept();
        if (s == null) break;
        s.setBlocking(false);
        var conn = new ClientConnection(s, nextConnId++);
        connections.push(conn);
        fresh.push(conn);
        Sys.println('[server] accepted conn id=${conn.id}');
      } catch (_:Dynamic) {
        // No pending connection; non-blocking would-block — stop polling.
        break;
      }
    }
    return fresh;
  }

  public function close():Void {
    for (c in connections) c.close();
    try listenSocket.close() catch (_:Dynamic) {}
  }
}
```

- [ ] **Step 3: Update `server/src/server/Main.hx` to boot the listener**

```haxe
package server;

import server.net.TcpServer;
import shared.Constants;

class Main {
  public static function main() {
    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    while (true) {
      srv.tickAccept();
      Sys.sleep(0.01);  // 100 Hz poll for M0; real loop refined in Task 17
    }
  }
}
```

- [ ] **Step 4: Build server**

```bash
make server
```

- [ ] **Step 5: Smoke-test manually**

In terminal A:

```bash
hl out/server.hl
```

Expected: `[server] listening on 127.0.0.1:7777`.

In terminal B:

```bash
nc 127.0.0.1 7777
```

Server should print `[server] accepted conn id=1`. Ctrl-C both.

- [ ] **Step 6: Commit**

```bash
git add server/src/server/net/TcpServer.hx server/src/server/net/ClientConnection.hx \
        server/src/server/Main.hx
git commit -m "feat(m0): TCP server accept loop"
```

---

## Task 14: Per-Connection Frame Buffer + Message Dispatch

Sockets give us byte streams. We need a buffer that accumulates bytes and yields whole frames.

**Files:**
- Modify: `server/src/server/net/ClientConnection.hx`
- Create: `server/src/server/net/MessageDispatcher.hx`
- Create: `server/test/TestFrameBuffer.hx`

- [ ] **Step 1: Write failing test for ClientConnection's frame buffering logic**

The frame buffering logic itself should be pure (no socket dependency) — extract a tested helper.

`server/test/TestFrameBuffer.hx`:

```haxe
package;

import utest.Assert;
import utest.Test;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import shared.proto.FrameCodec;
import server.net.FrameBuffer;

class TestFrameBuffer extends Test {
  function testCompleteFrameYields() {
    var fb = new FrameBuffer();
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, 7, Bytes.ofString("hi"));
    fb.feed(out.getBytes());
    var frames = fb.drainCompleteFrames();
    Assert.equals(1, frames.length);
    Assert.equals(7, frames[0].msgType);
  }

  function testPartialFrameWaits() {
    var fb = new FrameBuffer();
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, 7, Bytes.ofString("hi"));
    var full = out.getBytes();
    fb.feed(full.sub(0, 2));  // only the length bytes
    Assert.equals(0, fb.drainCompleteFrames().length);
    fb.feed(full.sub(2, full.length - 2));
    var frames = fb.drainCompleteFrames();
    Assert.equals(1, frames.length);
  }

  function testTwoBackToBackFrames() {
    var fb = new FrameBuffer();
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, 1, Bytes.ofString("a"));
    FrameCodec.writeFrame(out, 2, Bytes.ofString("bb"));
    fb.feed(out.getBytes());
    var frames = fb.drainCompleteFrames();
    Assert.equals(2, frames.length);
    Assert.equals(1, frames[0].msgType);
    Assert.equals(2, frames[1].msgType);
  }
}
```

Register in `server/test/TestMain.hx`.

- [ ] **Step 2: Run, verify failure (FrameBuffer missing)**

```bash
make server-test
```

- [ ] **Step 3: Implement `server/src/server/net/FrameBuffer.hx`**

```haxe
package server.net;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesBuffer;
import shared.Constants;

class FrameBuffer {
  var buf:Bytes = Bytes.alloc(0);

  public function new() {}

  public function feed(chunk:Bytes):Void {
    if (chunk == null || chunk.length == 0) return;
    var combined = new BytesBuffer();
    combined.add(buf);
    combined.add(chunk);
    buf = combined.getBytes();
  }

  public function drainCompleteFrames():Array<{msgType:Int, payload:Bytes}> {
    var out:Array<{msgType:Int, payload:Bytes}> = [];
    while (true) {
      if (buf.length < 2) break;
      var declaredLen = buf.getUInt16(0);
      if (declaredLen < 1 || declaredLen > Constants.MAX_FRAME_SIZE) {
        throw "FrameBuffer: invalid declared frame length " + declaredLen;
      }
      var totalLen = 2 + declaredLen;
      if (buf.length < totalLen) break;
      var frameBytes = buf.sub(0, totalLen);
      var inp = new BytesInput(frameBytes);
      out.push(shared.proto.FrameCodec.readFrame(inp));
      buf = buf.sub(totalLen, buf.length - totalLen);
    }
    return out;
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
make server-test
```

- [ ] **Step 5: Wire FrameBuffer into ClientConnection**

Replace `server/src/server/net/ClientConnection.hx`:

```haxe
package server.net;

import sys.net.Socket;
import haxe.io.Bytes;
import haxe.io.Error;

class ClientConnection {
  public var socket:Socket;
  public var id:Int;
  public var alive:Bool = true;
  public var frameBuffer:FrameBuffer = new FrameBuffer();

  public function new(socket:Socket, id:Int) {
    this.socket = socket;
    this.id = id;
  }

  /** Pull whatever bytes are available (non-blocking). Returns frames ready to dispatch. */
  public function pollFrames():Array<{msgType:Int, payload:Bytes}> {
    try {
      var chunk = Bytes.alloc(4096);
      var n = socket.input.readBytes(chunk, 0, chunk.length);
      if (n > 0) frameBuffer.feed(chunk.sub(0, n));
    } catch (e:haxe.io.Eof) {
      alive = false;
      return [];
    } catch (e:Dynamic) {
      // would-block / no data available; expected on non-blocking sockets
    }
    if (!alive) return [];
    try {
      return frameBuffer.drainCompleteFrames();
    } catch (e:Dynamic) {
      Sys.println('[server] conn ${id} protocol error: ${e} — dropping');
      alive = false;
      return [];
    }
  }

  public function sendFrame(msgType:Int, payload:Bytes):Void {
    if (!alive) return;
    try {
      var out = new haxe.io.BytesOutput();
      shared.proto.FrameCodec.writeFrame(out, msgType, payload);
      var bytes = out.getBytes();
      socket.output.writeBytes(bytes, 0, bytes.length);
    } catch (_:Dynamic) {
      alive = false;
    }
  }

  public function close():Void {
    alive = false;
    try socket.close() catch (_:Dynamic) {}
  }
}
```

- [ ] **Step 6: Implement `server/src/server/net/MessageDispatcher.hx`**

```haxe
package server.net;

import haxe.io.Bytes;

typedef Handler = (conn:ClientConnection, payload:Bytes) -> Void;

class MessageDispatcher {
  var handlers:Map<Int, Handler> = new Map();

  public function new() {}

  public function register(msgType:Int, handler:Handler):Void {
    handlers.set(msgType, handler);
  }

  public function dispatch(conn:ClientConnection, msgType:Int, payload:Bytes):Void {
    var h = handlers.get(msgType);
    if (h == null) {
      Sys.println('[server] conn ${conn.id}: no handler for msgType=$msgType');
      conn.close();
      return;
    }
    try {
      h(conn, payload);
    } catch (e:Dynamic) {
      Sys.println('[server] conn ${conn.id}: handler threw for msgType=$msgType: $e');
      conn.close();
    }
  }
}
```

- [ ] **Step 7: Build, verify clean compile**

```bash
make server
```

- [ ] **Step 8: Commit**

```bash
git add server/src/server/net/FrameBuffer.hx server/src/server/net/ClientConnection.hx \
        server/src/server/net/MessageDispatcher.hx server/test/TestFrameBuffer.hx server/test/TestMain.hx
git commit -m "feat(m0): FrameBuffer + dispatcher wiring"
```

---

## Task 15: Hello Handler

**Files:**
- Create: `server/src/server/auth/HelloHandler.hx`

- [ ] **Step 1: Implement `HelloHandler.hx`**

```haxe
package server.auth;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.Constants;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgType;

class HelloHandler {
  public static function handle(conn:ClientConnection, payload:Bytes):Void {
    var hello = MsgHello.deserialize(new BytesInput(payload));
    Sys.println('[server] conn ${conn.id} Hello version=${hello.protocolVersion} build=${hello.buildHash}');

    var ack = new MsgHelloAck();
    if (hello.protocolVersion != Constants.PROTOCOL_VERSION) {
      ack.ok = false;
      ack.reason = 'protocol mismatch (server=${Constants.PROTOCOL_VERSION} client=${hello.protocolVersion})';
    } else {
      ack.ok = true;
      ack.reason = "";
    }

    var out = new BytesOutput();
    ack.serialize(out);
    conn.sendFrame(MsgType.HELLO_ACK, out.getBytes());

    if (!ack.ok) conn.close();
  }
}
```

- [ ] **Step 2: Register handler in Main.hx**

Replace `server/src/server/Main.hx`:

```haxe
package server;

import server.net.TcpServer;
import server.net.MessageDispatcher;
import server.auth.HelloHandler;
import shared.Constants;
import shared.proto.MsgType;

class Main {
  public static function main() {
    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    var dispatcher = new MessageDispatcher();
    dispatcher.register(MsgType.HELLO, HelloHandler.handle);

    while (true) {
      srv.tickAccept();
      var i = 0;
      while (i < srv.connections.length) {
        var c = srv.connections[i];
        var frames = c.pollFrames();
        for (f in frames) dispatcher.dispatch(c, f.msgType, f.payload);
        if (!c.alive) {
          c.close();
          srv.connections.splice(i, 1);
        } else {
          i++;
        }
      }
      Sys.sleep(0.01);
    }
  }
}
```

- [ ] **Step 3: Build server**

```bash
make server
```

- [ ] **Step 4: Smoke-test against running server with a Haxe script** (the real client comes in Task 17; this is a quick check)

Create temporary `/tmp/hello-probe.hx`:

```haxe
import sys.net.Socket;
import sys.net.Host;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import shared.proto.FrameCodec;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgType;
import shared.Constants;

class HelloProbe {
  public static function main() {
    var s = new Socket();
    s.connect(new Host("127.0.0.1"), Constants.DEFAULT_SERVER_PORT);
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "probe";
    var payload = new BytesOutput();
    hello.serialize(payload);
    var frame = new BytesOutput();
    FrameCodec.writeFrame(frame, MsgType.HELLO, payload.getBytes());
    var bytes = frame.getBytes();
    s.output.writeBytes(bytes, 0, bytes.length);
    var resp = FrameCodec.readFrame(s.input);
    var ack = MsgHelloAck.deserialize(new BytesInput(resp.payload));
    Sys.println('got HelloAck: ok=${ack.ok} reason="${ack.reason}"');
    s.close();
  }
}
```

Build and run:

```bash
haxe -cp /tmp -cp shared/src -lib utest -main HelloProbe --hl /tmp/probe.hl
# In one terminal: hl out/server.hl
# In another:
hl /tmp/probe.hl
```

Expected: server prints `Hello version=1 build=probe`. Probe prints `got HelloAck: ok=true reason=""`.

- [ ] **Step 5: Commit**

```bash
git add server/src/server/auth/HelloHandler.hx server/src/server/Main.hx
git commit -m "feat(m0): Hello handler + dispatch wiring"
```

---

## Task 16: Login Handler + Session Tokens

**Files:**
- Create: `server/src/server/auth/LoginHandler.hx`
- Create: `server/src/server/auth/SessionStore.hx`
- Create: `server/test/TestSessionStore.hx`

- [ ] **Step 1: Write failing test for SessionStore**

```haxe
package;

import utest.Assert;
import utest.Test;
import server.auth.SessionStore;

class TestSessionStore extends Test {
  function testMintAndLookup() {
    var store = new SessionStore();
    var tok = store.mint(42);
    Assert.notNull(tok);
    Assert.isTrue(tok.length >= 16);
    Assert.equals(42, store.accountIdFor(tok));
  }

  function testUnknownTokenReturnsNull() {
    var store = new SessionStore();
    Assert.isNull(store.accountIdFor("nope"));
  }

  function testTokensAreUnique() {
    var store = new SessionStore();
    var t1 = store.mint(1);
    var t2 = store.mint(1);
    Assert.notEquals(t1, t2);
  }
}
```

Register in `server/test/TestMain.hx`.

- [ ] **Step 2: Run, verify failure**

```bash
make server-test
```

- [ ] **Step 3: Implement SessionStore**

```haxe
package server.auth;

class SessionStore {
  var tokens:Map<String, Int> = new Map();

  public function new() {}

  public function mint(accountId:Int):String {
    var tok = randomToken(24);
    tokens.set(tok, accountId);
    return tok;
  }

  public function accountIdFor(token:String):Null<Int> {
    return tokens.get(token);
  }

  public function revoke(token:String):Void {
    tokens.remove(token);
  }

  static function randomToken(nBytes:Int):String {
    var buf = new StringBuf();
    var hex = "0123456789abcdef";
    for (_ in 0...nBytes) {
      var b = Std.random(256);
      buf.add(hex.charAt((b >> 4) & 0xf));
      buf.add(hex.charAt(b & 0xf));
    }
    return buf.toString();
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
make server-test
```

- [ ] **Step 5: Implement LoginHandler**

```haxe
package server.auth;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import server.db.AccountDal;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgType;
import shared.security.PasswordHash;

class LoginHandler {
  var dal:AccountDal;
  var sessions:SessionStore;

  public function new(dal:AccountDal, sessions:SessionStore) {
    this.dal = dal;
    this.sessions = sessions;
  }

  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var login = MsgLogin.deserialize(new BytesInput(payload));
    var ack = new MsgLoginAck();

    var acct = dal.findByUsername(login.username);
    if (acct == null || !PasswordHash.verify(login.password, acct.passwordHash)) {
      ack.success = false;
      ack.sessionToken = "";
      ack.errorMsg = "invalid username or password";
      Sys.println('[server] conn ${conn.id} login FAIL user=${login.username}');
    } else {
      ack.success = true;
      ack.sessionToken = sessions.mint(acct.id);
      ack.errorMsg = "";
      Sys.println('[server] conn ${conn.id} login OK user=${login.username} acct=${acct.id}');
    }

    var out = new BytesOutput();
    ack.serialize(out);
    conn.sendFrame(MsgType.LOGIN_ACK, out.getBytes());
  }
}
```

- [ ] **Step 6: Wire LoginHandler into Main.hx**

Update `server/src/server/Main.hx`. After existing imports, add:

```haxe
import server.db.DbClient;
import server.db.AccountDal;
import server.auth.LoginHandler;
import server.auth.SessionStore;
```

After `dispatcher.register(MsgType.HELLO, HelloHandler.handle);` add:

```haxe
    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var dal = new AccountDal(db);
    var sessions = new SessionStore();
    var loginHandler = new LoginHandler(dal, sessions);
    dispatcher.register(MsgType.LOGIN, loginHandler.handle);
```

- [ ] **Step 7: Build server**

```bash
make server
```

- [ ] **Step 8: Commit**

```bash
git add server/src/server/auth/SessionStore.hx server/src/server/auth/LoginHandler.hx \
        server/src/server/Main.hx server/test/TestSessionStore.hx server/test/TestMain.hx
git commit -m "feat(m0): Login handler + session tokens"
```

---

## Task 17: Integration Test — End-to-End Login

A real, scriptable integration test: boot server, connect, send Hello + Login, verify LoginAck. No UI involved.

**Files:**
- Create: `server/test/TestLoginFlow.hx`

- [ ] **Step 1: Write the integration test**

```haxe
package;

import utest.Assert;
import utest.Async;
import utest.Test;
import sys.net.Socket;
import sys.net.Host;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.db.DbClient;
import server.db.AccountDal;
import shared.Constants;
import shared.proto.FrameCodec;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgType;
import shared.security.PasswordHash;

class TestLoginFlow extends Test {
  var db:DbClient;
  var dal:AccountDal;

  function setupClass() {
    db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    dal = new AccountDal(db);
    db.exec("DELETE FROM accounts WHERE username = ?", ["test_login_user"]);
    dal.create("test_login_user", PasswordHash.hash("test_login_pw"));
  }

  function teardownClass() {
    db.exec("DELETE FROM accounts WHERE username = ?", ["test_login_user"]);
    db.close();
  }

  // PRECONDITION: server is running on localhost:7777 with a fresh DB.
  // This test assumes the operator started `hl out/server.hl` in another terminal.
  // CI script (run-integration.sh, Task 18) automates this.

  function testHelloAndLoginRoundTrip() {
    var s = new Socket();
    s.connect(new Host("127.0.0.1"), Constants.DEFAULT_SERVER_PORT);

    // --- Hello ---
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "integration-test";
    var helloPayload = new BytesOutput();
    hello.serialize(helloPayload);
    var helloFrame = new BytesOutput();
    FrameCodec.writeFrame(helloFrame, MsgType.HELLO, helloPayload.getBytes());
    var hb = helloFrame.getBytes();
    s.output.writeBytes(hb, 0, hb.length);

    var ackFrame = FrameCodec.readFrame(s.input);
    Assert.equals(MsgType.HELLO_ACK, (ackFrame.msgType : Int));
    var helloAck = MsgHelloAck.deserialize(new BytesInput(ackFrame.payload));
    Assert.isTrue(helloAck.ok);

    // --- Login (correct password) ---
    var login = new MsgLogin();
    login.username = "test_login_user";
    login.password = "test_login_pw";
    var loginPayload = new BytesOutput();
    login.serialize(loginPayload);
    var loginFrame = new BytesOutput();
    FrameCodec.writeFrame(loginFrame, MsgType.LOGIN, loginPayload.getBytes());
    var lb = loginFrame.getBytes();
    s.output.writeBytes(lb, 0, lb.length);

    var loginAckFrame = FrameCodec.readFrame(s.input);
    Assert.equals(MsgType.LOGIN_ACK, (loginAckFrame.msgType : Int));
    var loginAck = MsgLoginAck.deserialize(new BytesInput(loginAckFrame.payload));
    Assert.isTrue(loginAck.success);
    Assert.isTrue(loginAck.sessionToken.length >= 16);
    Assert.equals("", loginAck.errorMsg);

    s.close();
  }

  function testLoginWithBadPasswordFails() {
    var s = new Socket();
    s.connect(new Host("127.0.0.1"), Constants.DEFAULT_SERVER_PORT);

    // Hello first
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "integration-test";
    var hp = new BytesOutput(); hello.serialize(hp);
    var hf = new BytesOutput(); FrameCodec.writeFrame(hf, MsgType.HELLO, hp.getBytes());
    var hb = hf.getBytes(); s.output.writeBytes(hb, 0, hb.length);
    FrameCodec.readFrame(s.input);  // consume HelloAck

    var login = new MsgLogin();
    login.username = "test_login_user";
    login.password = "WRONG";
    var lp = new BytesOutput(); login.serialize(lp);
    var lf = new BytesOutput(); FrameCodec.writeFrame(lf, MsgType.LOGIN, lp.getBytes());
    var lb = lf.getBytes(); s.output.writeBytes(lb, 0, lb.length);

    var ackFrame = FrameCodec.readFrame(s.input);
    var ack = MsgLoginAck.deserialize(new BytesInput(ackFrame.payload));
    Assert.isFalse(ack.success);
    Assert.equals("", ack.sessionToken);
    Assert.isTrue(ack.errorMsg.length > 0);

    s.close();
  }
}
```

Register in `server/test/TestMain.hx`.

- [ ] **Step 2: Create CI orchestration script `run-integration.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Bring up MySQL
docker-compose up -d mysql
for _ in {1..60}; do
  if docker inspect haxecraft-mysql 2>/dev/null | grep -q '"Status": "healthy"'; then break; fi
  sleep 1
done

# Apply migrations (idempotent)
./db/apply-migrations.sh

# Build
make all

# Start server in background
hl out/server.hl &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 1  # give server a moment to listen

# Run server tests (which include the login-flow integration test)
make server-test
```

- [ ] **Step 3: Make script executable**

```bash
chmod +x run-integration.sh
```

- [ ] **Step 4: Run the integration test**

```bash
./run-integration.sh
```

Expected: all tests pass, server prints `login OK user=test_login_user` and `login FAIL user=test_login_user`.

- [ ] **Step 5: Commit**

```bash
git add server/test/TestLoginFlow.hx server/test/TestMain.hx run-integration.sh
git commit -m "test(m0): end-to-end login flow integration test"
```

---

## Task 18: Client TCP Connection Layer

The Heaps client wraps a `sys.net.Socket` and a FrameBuffer (the same logic as server-side). Reuse server's `FrameBuffer` by promoting it to `shared/`.

**Files:**
- Move: `server/src/server/net/FrameBuffer.hx` → `shared/src/shared/proto/FrameBuffer.hx` (rename package)
- Modify: every server file importing `server.net.FrameBuffer` to use `shared.proto.FrameBuffer`
- Create: `client/src/client/net/TcpConnection.hx`

- [ ] **Step 1: Move FrameBuffer to shared/**

```bash
git mv server/src/server/net/FrameBuffer.hx shared/src/shared/proto/FrameBuffer.hx
```

Edit the moved file's `package` line:

```haxe
package shared.proto;
```

Update any internal references (the only one was `shared.proto.FrameCodec.readFrame` — already qualified, no change needed).

- [ ] **Step 2: Update server imports**

In `server/src/server/net/ClientConnection.hx`, replace `server.net.FrameBuffer` references:
- Field type: `public var frameBuffer:shared.proto.FrameBuffer = new shared.proto.FrameBuffer();`
- Or add an import: `import shared.proto.FrameBuffer;` (then leave field as `FrameBuffer`)

In `server/test/TestFrameBuffer.hx`, replace `import server.net.FrameBuffer;` with `import shared.proto.FrameBuffer;`.

- [ ] **Step 3: Verify server still builds and tests pass**

```bash
make all && ./run-integration.sh
```

Expected: clean build, all tests pass.

- [ ] **Step 4: Create `client/src/client/net/TcpConnection.hx`**

```haxe
package client.net;

import sys.net.Socket;
import sys.net.Host;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import shared.proto.FrameBuffer;
import shared.proto.FrameCodec;

enum ConnectionState {
  DISCONNECTED;
  CONNECTING;
  CONNECTED;
  CLOSED;
}

class TcpConnection {
  var socket:Socket;
  public var state(default, null):ConnectionState = DISCONNECTED;
  var frameBuffer:FrameBuffer = new FrameBuffer();

  public function new() {}

  public function connect(host:String, port:Int):Void {
    state = CONNECTING;
    socket = new Socket();
    try {
      socket.connect(new Host(host), port);
      socket.setBlocking(false);
      state = CONNECTED;
    } catch (e:Dynamic) {
      state = CLOSED;
      throw 'TcpConnection: connect failed: $e';
    }
  }

  public function sendFrame(msgType:Int, payload:Bytes):Void {
    if (state != CONNECTED) return;
    var out = new BytesOutput();
    FrameCodec.writeFrame(out, msgType, payload);
    var b = out.getBytes();
    try {
      socket.output.writeBytes(b, 0, b.length);
    } catch (e:Dynamic) {
      state = CLOSED;
    }
  }

  /** Returns frames available this poll. Call once per Heaps update tick. */
  public function poll():Array<{msgType:Int, payload:Bytes}> {
    if (state != CONNECTED) return [];
    try {
      var chunk = Bytes.alloc(4096);
      var n = socket.input.readBytes(chunk, 0, chunk.length);
      if (n > 0) frameBuffer.feed(chunk.sub(0, n));
    } catch (e:haxe.io.Eof) {
      state = CLOSED;
      return [];
    } catch (e:Dynamic) {
      // would-block; ignore
    }
    try {
      return frameBuffer.drainCompleteFrames();
    } catch (e:Dynamic) {
      state = CLOSED;
      return [];
    }
  }

  public function close():Void {
    state = CLOSED;
    try socket.close() catch (_:Dynamic) {}
  }
}
```

- [ ] **Step 5: Build client (still using stub Main)**

```bash
make client
```

Expected: clean build.

- [ ] **Step 6: Commit**

```bash
git add shared/src/shared/proto/FrameBuffer.hx server/src/server/net/ClientConnection.hx \
        server/test/TestFrameBuffer.hx client/src/client/net/TcpConnection.hx
git commit -m "refactor(m0): promote FrameBuffer to shared/ + add client TcpConnection"
```

---

## Task 19: Client UI — Login Screen + Welcome Screen

A minimal Heaps UI: text field for username, text field for password, login button. On success, show "Welcome, <username>".

**Files:**
- Modify: `client/src/client/Main.hx`
- Create: `client/src/client/net/ClientDispatcher.hx`
- Create: `client/src/client/ui/LoginScreen.hx`
- Create: `client/src/client/ui/WelcomeScreen.hx`

- [ ] **Step 1: Create `ClientDispatcher.hx`**

```haxe
package client.net;

import haxe.io.Bytes;

typedef ClientHandler = (payload:Bytes) -> Void;

class ClientDispatcher {
  var handlers:Map<Int, ClientHandler> = new Map();

  public function new() {}

  public function on(msgType:Int, handler:ClientHandler):Void {
    handlers.set(msgType, handler);
  }

  public function dispatch(msgType:Int, payload:Bytes):Void {
    var h = handlers.get(msgType);
    if (h != null) h(payload);
    else trace('[client] no handler for msgType=$msgType');
  }
}
```

- [ ] **Step 2: Create `LoginScreen.hx`**

We use Heaps' built-in `h2d.Text` and a minimal homegrown text-entry (Heaps does not ship a polished input widget; for M0, accept input via SDL key events and render manually). The bar is low — this is a smoke-test UI, not a real login screen.

```haxe
package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.Event;
import hxd.res.DefaultFont;

class LoginScreen extends Object {
  public var onSubmit:(username:String, password:String) -> Void;

  var usernameField:Text;
  var passwordField:Text;
  var statusField:Text;
  var focused:Int = 0;  // 0 = username, 1 = password
  var usernameValue:String = "";
  var passwordValue:String = "";

  public function new(parent:Object) {
    super(parent);
    var font = DefaultFont.get();

    var title = new Text(font, this);
    title.text = "haxecraft — login";
    title.x = 40; title.y = 40; title.scale(2);

    var unameLabel = new Text(font, this);
    unameLabel.text = "username:";
    unameLabel.x = 40; unameLabel.y = 120;

    usernameField = new Text(font, this);
    usernameField.x = 160; usernameField.y = 120;
    usernameField.text = "[]";

    var pwLabel = new Text(font, this);
    pwLabel.text = "password:";
    pwLabel.x = 40; pwLabel.y = 160;

    passwordField = new Text(font, this);
    passwordField.x = 160; passwordField.y = 160;
    passwordField.text = "";

    statusField = new Text(font, this);
    statusField.x = 40; statusField.y = 220;
    statusField.text = "Tab to switch field. Enter to submit.";

    refresh();
  }

  public function handleKey(e:Event):Void {
    if (e.kind != EKeyDown) return;
    switch e.keyCode {
      case hxd.Key.TAB:
        focused = 1 - focused;
        refresh();
      case hxd.Key.ENTER:
        if (usernameValue.length > 0 && passwordValue.length > 0) {
          if (onSubmit != null) onSubmit(usernameValue, passwordValue);
          setStatus("connecting...");
        }
      case hxd.Key.BACKSPACE:
        if (focused == 0 && usernameValue.length > 0)
          usernameValue = usernameValue.substr(0, usernameValue.length - 1);
        else if (focused == 1 && passwordValue.length > 0)
          passwordValue = passwordValue.substr(0, passwordValue.length - 1);
        refresh();
      default:
        if (e.charCode > 31 && e.charCode < 127) {
          var ch = String.fromCharCode(e.charCode);
          if (focused == 0) usernameValue += ch;
          else passwordValue += ch;
          refresh();
        }
    }
  }

  function refresh():Void {
    usernameField.text = (focused == 0 ? "> " : "  ") + usernameValue + (focused == 0 ? "_" : "");
    var masked = StringTools.lpad("", "*", passwordValue.length);
    passwordField.text = (focused == 1 ? "> " : "  ") + masked + (focused == 1 ? "_" : "");
  }

  public function setStatus(s:String):Void {
    statusField.text = s;
  }
}
```

- [ ] **Step 3: Create `WelcomeScreen.hx`**

```haxe
package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.res.DefaultFont;

class WelcomeScreen extends Object {
  public function new(parent:Object, username:String) {
    super(parent);
    var font = DefaultFont.get();
    var t = new Text(font, this);
    t.text = 'Welcome, $username';
    t.x = 40; t.y = 100; t.scale(3);
  }
}
```

- [ ] **Step 4: Wire it all together in Main.hx**

Replace `client/src/client/Main.hx`:

```haxe
package client;

import hxd.App;
import hxd.Event;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import client.net.TcpConnection;
import client.net.ClientDispatcher;
import client.ui.LoginScreen;
import client.ui.WelcomeScreen;
import shared.Constants;
import shared.proto.FrameCodec;
import shared.proto.MsgHello;
import shared.proto.MsgHelloAck;
import shared.proto.MsgLogin;
import shared.proto.MsgLoginAck;
import shared.proto.MsgType;

class Main extends App {
  var conn:TcpConnection;
  var dispatcher:ClientDispatcher;
  var loginScreen:LoginScreen;
  var welcomeScreen:WelcomeScreen;
  var pendingUsername:String = "";

  static function main() {
    new Main();
  }

  override function init() {
    dispatcher = new ClientDispatcher();
    dispatcher.on(MsgType.HELLO_ACK, onHelloAck);
    dispatcher.on(MsgType.LOGIN_ACK, onLoginAck);

    loginScreen = new LoginScreen(s2d);
    loginScreen.onSubmit = onLoginSubmit;

    hxd.Window.getInstance().addEventTarget(onEvent);
  }

  function onEvent(e:Event):Void {
    if (loginScreen != null && loginScreen.parent != null) loginScreen.handleKey(e);
  }

  function onLoginSubmit(username:String, password:String):Void {
    pendingUsername = username;
    try {
      conn = new TcpConnection();
      conn.connect(Constants.DEFAULT_SERVER_HOST, Constants.DEFAULT_SERVER_PORT);
    } catch (e:Dynamic) {
      loginScreen.setStatus('connect failed: $e');
      return;
    }
    // Send Hello immediately
    var hello = new MsgHello();
    hello.protocolVersion = Constants.PROTOCOL_VERSION;
    hello.buildHash = "client-m0";
    var p = new BytesOutput(); hello.serialize(p);
    conn.sendFrame(MsgType.HELLO, p.getBytes());
    // Stash credentials until HelloAck
    pendingPassword = password;
  }

  var pendingPassword:String = "";

  function onHelloAck(payload:Bytes):Void {
    var ack = MsgHelloAck.deserialize(new BytesInput(payload));
    if (!ack.ok) {
      loginScreen.setStatus('hello rejected: ${ack.reason}');
      conn.close();
      return;
    }
    // Now send Login
    var login = new MsgLogin();
    login.username = pendingUsername;
    login.password = pendingPassword;
    pendingPassword = "";  // don't keep it around
    var p = new BytesOutput(); login.serialize(p);
    conn.sendFrame(MsgType.LOGIN, p.getBytes());
  }

  function onLoginAck(payload:Bytes):Void {
    var ack = MsgLoginAck.deserialize(new BytesInput(payload));
    if (!ack.success) {
      loginScreen.setStatus('login failed: ${ack.errorMsg}');
      return;
    }
    loginScreen.remove();
    loginScreen = null;
    welcomeScreen = new WelcomeScreen(s2d, pendingUsername);
  }

  override function update(dt:Float) {
    if (conn != null && conn.state == CONNECTED) {
      var frames = conn.poll();
      for (f in frames) dispatcher.dispatch(f.msgType, f.payload);
    }
  }
}
```

- [ ] **Step 5: Build client**

```bash
make client
```

Expected: clean build (a couple of warnings about unused imports are OK; errors are not).

- [ ] **Step 6: Commit**

```bash
git add client/src/client/Main.hx client/src/client/net/ClientDispatcher.hx \
        client/src/client/ui/LoginScreen.hx client/src/client/ui/WelcomeScreen.hx
git commit -m "feat(m0): client login UI + hello/login dispatch"
```

---

## Task 20: Run Scripts + Manual End-to-End Demo

**Files:**
- Create: `run-server.sh`
- Create: `run-client.sh`
- Create: `README-M0.md`

- [ ] **Step 1: Create `run-server.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
docker-compose up -d mysql
for _ in {1..60}; do
  if docker inspect haxecraft-mysql 2>/dev/null | grep -q '"Status": "healthy"'; then break; fi
  sleep 1
done
./db/apply-migrations.sh
make server
exec hl out/server.hl
```

- [ ] **Step 2: Create `run-client.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
make client
exec hl out/client.hl
```

- [ ] **Step 3: Make executable**

```bash
chmod +x run-server.sh run-client.sh
```

- [ ] **Step 4: Write `README-M0.md`**

```markdown
# M0 Foundation — Quickstart

## Prereqs

- Haxe 4.3+
- HashLink 1.16+
- Docker + Docker Compose
- `haxelib install heaps hlsdl utest`
- (MySQL accessed via Haxe stdlib `sys.db.Mysql` — no extra haxelib needed)

## Create an account

```bash
docker-compose up -d mysql
./db/apply-migrations.sh
make server-cli
hl out/server-cli.hl create-account joshua hunter2
```

## Run the server

```bash
./run-server.sh
```

Server listens on `127.0.0.1:7777`.

## Run the client

```bash
./run-client.sh
```

A window opens with a login form. Enter the account credentials. On success, "Welcome, <username>" appears.

## Run the test suite

```bash
make test               # shared unit tests
./run-integration.sh    # server + integration tests (requires Docker)
```
```

- [ ] **Step 5: Manual demo**

In terminal A:

```bash
./run-server.sh
```

Wait for `[server] listening on 127.0.0.1:7777`.

In terminal B (first time only):

```bash
make server-cli
hl out/server-cli.hl create-account joshua hunter2
```

In terminal C:

```bash
./run-client.sh
```

Window opens. Type `joshua`, Tab, `hunter2`, Enter. Window shows "Welcome, joshua".

Server (terminal A) logs:

```
[server] accepted conn id=N
[server] conn N Hello version=1 build=client-m0
[server] conn N login OK user=joshua acct=1
```

- [ ] **Step 6: Commit**

```bash
git add run-server.sh run-client.sh README-M0.md
git commit -m "docs(m0): quickstart + run scripts"
```

---

## Task 21: M0 Definition-of-Done Verification

A final pass that confirms every M0 acceptance criterion from the top of this plan.

- [ ] **Step 1: Build everything from a clean state**

```bash
make clean
make all
```

Expected: `out/shared-test.hl`, `out/server.hl`, `out/server-cli.hl`, `out/client.hl` all present, no errors.

- [ ] **Step 2: Run full test suite**

```bash
make test
./run-integration.sh
```

Expected: every test passes.

- [ ] **Step 3: Bring up the demo end-to-end**

Follow `README-M0.md` quickstart. Confirm Welcome screen appears.

- [ ] **Step 4: Verify untouched haxecraft single-player still builds**

```bash
haxe build.hxml
```

Expected: existing `haxecraft.hl` builds without errors (single-player game unaffected).

- [ ] **Step 5: Update top-level README (if any) with a pointer to M0 docs**

Check if `README.md` exists at repo root. If yes, add a section:

```markdown
## Multiplayer (M0)

See `README-M0.md` for the multiplayer foundation quickstart.
Spec: `docs/superpowers/specs/2026-05-14-haxecraft-mmo-design.md`
```

If no `README.md` exists, skip.

- [ ] **Step 6: Tag the milestone**

```bash
git tag -a m0-foundation -m "M0: network + auth foundation complete"
```

(Push tag is the operator's call — do not push without explicit instruction.)

- [ ] **Step 7: Commit the README change if any**

```bash
git add README.md
git commit -m "docs(m0): link to multiplayer quickstart"
```

(Skip if step 5 was a no-op.)

---

## Spec Coverage Check

Mapping spec requirements (M0 section + relevant cross-cutting design sections) to tasks:

| Spec requirement | Tasks |
|---|---|
| Repo restructure to shared/client/server/tools | Task 1 (adds new dirs alongside `src/`; migration of haxecraft engine itself deferred to M1) |
| Shared protocol skeleton: `@:serializable` macro | Task 6 |
| Frame codec (length-prefixed binary) | Tasks 3, 4 |
| Version handshake (Hello/HelloAck) | Tasks 7, 15, 19 |
| HL server skeleton: TCP listen | Task 13 |
| Frame I/O | Task 14 |
| Message dispatch | Task 14 |
| Heaps client connects, sends Hello | Tasks 18, 19 |
| Database up (Docker for dev) — MySQL post-research | Task 8 |
| Schema applied | Task 8 |
| Account create + login flow end-to-end | Tasks 10, 11, 12, 16, 19 |
| Code-sharing discipline (shared/ pure, no platform deps) | Task 1 build configs enforce; FrameBuffer promotion in Task 18 demonstrates |
| Anti-cheat by construction (intents-only) | Login is the only intent in M0; pattern set by message classes |
| TLS for gateway | **Deferred** — M0 is localhost-only; explicit M1 task |
| Encryption of credentials over the wire | **Deferred with TLS** — flagged in README-M0 and at top of plan |
| Layer 1 unit tests | Tasks 2, 3, 4, 5, 6, 7, 9, 14, 16 |
| Layer 3 integration test | Task 17 |
| Headless client harness | **Deferred to M1** (per spec — M1 task) |

Items deferred past M0 are explicitly called out at the top of the plan ("Out of scope for M0").

## Placeholder Scan

Scanned for: TBD, TODO, "implement later", "similar to Task N", references to undefined types.

Findings + fixes (applied inline above):
- Task 10 was originally a research-then-implement structure for a Postgres driver, but research during planning determined no maintained HL Postgres driver exists. Task 10 is now a straightforward implementation over `sys.db.Mysql` (Haxe stdlib). The database choice is documented in the plan header and the spec was updated to match.
- Task 9 same pattern for password hashing, with concrete PBKDF2 fallback inline so progress is unblocked.
- No "similar to Task N" references; every code step has explicit code.

## Type Consistency Check

- `MsgType` values used consistently (HELLO=1, HELLO_ACK=2, LOGIN=3, LOGIN_ACK=4, ERROR=5) across Tasks 5, 7, 15, 16, 17, 19.
- `FrameBuffer` lives in `shared.proto` from Task 18 onward; before Task 18 it was in `server.net`. Server imports updated in Task 18 step 2.
- `Account` typedef defined in Task 11, used in Task 16 LoginHandler — fields `id`, `username`, `passwordHash` consistent.
- `ClientConnection` field name `frameBuffer` consistent in Task 14 step 5 and never re-named.
- `SessionStore` method names `mint(accountId)`, `accountIdFor(token)`, `revoke(token)` consistent across Tasks 16 and (future) handoff code.
- `TcpConnection.poll()` returns `Array<{msgType:Int, payload:Bytes}>` — matches what `ClientDispatcher.dispatch(msgType, payload)` expects.

No drift detected.
