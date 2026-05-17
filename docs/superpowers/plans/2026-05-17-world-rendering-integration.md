# World Rendering Integration + Passive Terrain — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the MMO client's colored-square rendering with the original haxecraft sprite-atlas pipeline, and expand the server tile vocabulary to 10 passive terrain types so the world renders as real pixel art.

**Architecture:** The original's `engine.gfx` package (`Screen`, `GpuRenderer`, `SpriteRegistry`) is a Heaps-based renderer. It is promoted to a new top-level `engine/` module shared by the legacy game and the MMO client. The MMO client gains a `ZoneRenderer` that draws the world into a fixed 320×240 `Screen` buffer. Terrain is flat (one sprite per tile, no neighbor blending); the local and remote players render with the original animated player sprite. No server-authority or wire-protocol change — only the offline-authored tile set grows.

**Tech Stack:** Haxe 4.3, HashLink (HLC native on Apple Silicon), Heaps (`h2d`), utest.

**Spec:** `docs/superpowers/specs/2026-05-17-world-rendering-integration-design.md`

**Note on the spec's Section 1:** the spec names `engine.gfx.ChromeText` as the file coupled to `game.SpriteNames`. The actual coupled file is `engine.gfx.Font` (and `engine.Engine`, outside `gfx`). Neither is on the MMO client's compile graph for this sub-project — the client uses only `Screen`, `GpuRenderer`, `SpriteRegistry`, `SpriteSheet`, `AtlasSheet`, `SpriteAtlas`, `SpriteId`, `Color`, `PaletteRegistry`, `CompositeSprite`, all of which are `game`-free. So no decoupling work is required; `Font.hx` keeps its import and is simply never compiled by the client. This plan reflects that reality.

---

## File Structure

**New files:**
- `engine/src/engine/...` — the entire `src/engine` tree, moved (Task 1).
- `client/src/client/render/SpriteCatalog.hx` — pure data: `TileType` → terrain sprite cell + palette; the player palette constant (Task 5).
- `client/src/client/render/ZoneRenderer.hx` — owns `Screen`/`GpuRenderer`/`SpriteRegistry`; draws terrain + entities (Tasks 6–7).
- `client/src/client/render/EntityVisual.hx` — per-entity interpolation + facing/anim state (Task 7).
- `client/build-client-test.hxml` — headless client unit-test build (Task 5).
- `client/test/TestMain.hx`, `client/test/TestSpriteCatalog.hx` — client test harness (Task 5).
- `shared/test/TestTileType.hx` — tile walkability tests (Task 3).
- `README-SUBPROJECT1.md` — eyes-on manual test guide (Task 8).

**Modified files:**
- `build.hxml`, `build_macos.sh` — add `engine/src` to the legacy game's classpath (Task 1).
- `client/build-client.hxml`, `build_native.sh`, `build_native.ps1` — add `engine/src` to the client classpath; add the `client-test` target (Tasks 2, 5).
- `Makefile` — add `client-test` target (Task 5).
- `shared/src/shared/world/TileType.hx` — 10 tile types (Task 3).
- `shared/test/TestMain.hx` — register `TestTileType` (Task 3).
- `tools/worldgen-tmx/src/Main.hx` — place the new tiles; update TMX `tilecount` (Task 4).
- `res/maps/starter.tmx` — regenerated (Task 4).
- `client/src/client/Main.hx` — wire in `ZoneRenderer`; drop `Camera`/`WorldRenderer`/`EntityRenderer` (Tasks 6–7).

**Deleted files (Task 8):**
- `client/src/client/game/Camera.hx`, `client/src/client/game/WorldRenderer.hx`, `client/src/client/game/EntityRenderer.hx`, `client/src/client/ui/InZoneScreen.hx`.

---

## Task 1: Promote `src/engine` to an `engine/` module

**Files:**
- Move: `src/engine/` → `engine/src/engine/`
- Modify: `build.hxml`, `build_macos.sh`

- [ ] **Step 1: Move the engine tree**

```bash
mkdir -p engine/src
git mv src/engine engine/src/engine
```

Expected: `engine/src/engine/gfx/Screen.hx` etc. now exist; `src/` contains only `src/game/`.

- [ ] **Step 2: Add `engine/src` to the legacy game's hxml classpath**

In `build.hxml`, change:

```
-cp src
-main game.Game
```

to:

```
-cp src
-cp engine/src
-main game.Game
```

- [ ] **Step 3: Add `engine/src` to the legacy game's macOS build script**

In `build_macos.sh`, find the `haxe` invocation (the "Generating C code..." section):

```
haxe -lib heaps -lib hlsdl -lib hlopenal -D hlopenal -cp src -main game.Game -D resourcesPath=res -hl out/main.c
```

Change `-cp src` to `-cp src -cp engine/src`:

```
haxe -lib heaps -lib hlsdl -lib hlopenal -D hlopenal -cp src -cp engine/src -main game.Game -D resourcesPath=res -hl out/main.c
```

- [ ] **Step 4: Verify the legacy game still compiles**

Run: `haxe build.hxml`
Expected: compiles with no errors (it produces `haxecraft.hl`; warnings are acceptable).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: promote src/engine to a top-level engine/ module

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Add the `engine/` module to the MMO client build

**Files:**
- Modify: `client/build-client.hxml`, `build_native.sh`, `build_native.ps1`

- [ ] **Step 1: Add `engine/src` to the client hxml**

In `client/build-client.hxml`, change:

```
-cp src
-cp ../shared/src
```

to:

```
-cp src
-cp ../shared/src
-cp ../engine/src
```

- [ ] **Step 2: Add `engine/src` to the native client build (bash)**

In `build_native.sh`, in `build_client()`, the `gen_c client` call currently reads:

```bash
  gen_c client client -cp src -cp ../shared/src -lib heaps -lib hlsdl \
    -main client.Main -D resourcesPath=../res -D analyzer-optimize
```

Add `-cp ../engine/src`:

```bash
  gen_c client client -cp src -cp ../shared/src -cp ../engine/src -lib heaps -lib hlsdl \
    -main client.Main -D resourcesPath=../res -D analyzer-optimize
```

- [ ] **Step 3: Add `engine/src` to the native client build (PowerShell)**

In `build_native.ps1`, in `Build-Client`, the `Gen-C` call currently reads:

```powershell
  Gen-C 'client' 'client' @('-cp','src','-cp','..\shared\src','-lib','heaps','-lib','hlsdl','-main','client.Main','-D','resourcesPath=..\res','-D','analyzer-optimize')
```

Add `'-cp','..\engine\src'`:

```powershell
  Gen-C 'client' 'client' @('-cp','src','-cp','..\shared\src','-cp','..\engine\src','-lib','heaps','-lib','hlsdl','-main','client.Main','-D','resourcesPath=..\res','-D','analyzer-optimize')
```

- [ ] **Step 4: Verify the client still compiles**

Run: `./build_native.sh client`
Expected: `clang -> bin/client`, exit 0. (The client does not reference `engine` yet — this only proves the classpath addition is harmless.)

- [ ] **Step 5: Commit**

```bash
git add client/build-client.hxml build_native.sh build_native.ps1
git commit -m "build: add engine/ module to the MMO client classpath

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Expand `TileType` to 10 passive types

**Files:**
- Modify: `shared/src/shared/world/TileType.hx`
- Test: `shared/test/TestTileType.hx` (create), `shared/test/TestMain.hx` (modify)

- [ ] **Step 1: Write the failing test**

Create `shared/test/TestTileType.hx`:

```haxe
package;

import utest.Test;
import utest.Assert;
import shared.world.TileType;

class TestTileType extends Test {
  function testWalkableTypes() {
    Assert.isTrue((GRASS : TileType).isWalkable());
    Assert.isTrue((SAND : TileType).isWalkable());
    Assert.isTrue((DIRT : TileType).isWalkable());
    Assert.isTrue((FLOWER : TileType).isWalkable());
  }

  function testBlockedTypes() {
    Assert.isFalse((WATER : TileType).isWalkable());
    Assert.isFalse((STONE : TileType).isWalkable());
    Assert.isFalse((ROCK : TileType).isWalkable());
    Assert.isFalse((TREE : TileType).isWalkable());
    Assert.isFalse((LAVA : TileType).isWalkable());
    Assert.isFalse((CACTUS : TileType).isWalkable());
  }

  function testIdsAreContiguous() {
    Assert.equals(1, (GRASS : Int));
    Assert.equals(7, (DIRT : Int));
    Assert.equals(8, (FLOWER : Int));
    Assert.equals(9, (LAVA : Int));
    Assert.equals(10, (CACTUS : Int));
  }
}
```

Register it in `shared/test/TestMain.hx` — add after the `TestTmxParser` line:

```haxe
    r.addCase(new TestTmxParser());
    r.addCase(new TestTileType());
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `make test`
Expected: FAIL — compile error, `DIRT`/`FLOWER`/`LAVA`/`CACTUS` not defined in `TileType`.

- [ ] **Step 3: Add the new tile types**

Replace the body of `shared/src/shared/world/TileType.hx` with:

```haxe
package shared.world;

enum abstract TileType(Int) to Int from Int {
  var GRASS = 1;
  var SAND = 2;
  var WATER = 3;
  var STONE = 4;
  var ROCK = 5;
  var TREE = 6;
  var DIRT = 7;
  var FLOWER = 8;
  var LAVA = 9;
  var CACTUS = 10;

  public inline function isWalkable():Bool {
    return switch (cast this : TileType) {
      case GRASS | SAND | DIRT | FLOWER: true;
      case WATER | STONE | ROCK | TREE | LAVA | CACTUS: false;
      default: false;
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test`
Expected: PASS — `ALL TESTS OK`, `TestTileType` cases green, total successes increased.

- [ ] **Step 5: Commit**

```bash
git add shared/src/shared/world/TileType.hx shared/test/TestTileType.hx shared/test/TestMain.hx
git commit -m "feat(world): expand TileType to 10 passive terrain types

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Place the new tiles in worldgen and regenerate the map

**Files:**
- Modify: `tools/worldgen-tmx/src/Main.hx`
- Regenerate: `res/maps/starter.tmx`

The current `generate()` produces WATER/SAND/GRASS/STONE/ROCK by noise band, then scatters TREE on grass. This task adds: DIRT patches in grass, FLOWER scattered on grass, LAVA in rock, CACTUS on sand. The TMX `<tileset tilecount="6">` becomes `tilecount="10"`.

- [ ] **Step 1: Extend the scatter pass in `generate()`**

In `tools/worldgen-tmx/src/Main.hx`, the `generate()` function ends with a scatter loop that places TREE. Replace that final scatter loop (from `var rng = SEED;` through the `return tiles;`) with:

```haxe
    var rng = SEED;
    for (y in 0...height) {
      for (x in 0...width) {
        rng = mix32(rng + x * 374761393 + y * 668265263);
        var idx = y * width + x;
        var t = tiles[idx];
        var roll = rng & 0xff;
        if (t == (TileType.GRASS : Int)) {
          if (roll < 6)        tiles[idx] = (TileType.TREE : Int);
          else if (roll < 30)  tiles[idx] = (TileType.DIRT : Int);
          else if (roll < 38)  tiles[idx] = (TileType.FLOWER : Int);
        } else if (t == (TileType.SAND : Int)) {
          if (roll < 5)        tiles[idx] = (TileType.CACTUS : Int);
        } else if (t == (TileType.ROCK : Int)) {
          if (roll < 8)        tiles[idx] = (TileType.LAVA : Int);
        }
      }
    }
    return tiles;
```

- [ ] **Step 2: Update the TMX tileset count**

In `tools/worldgen-tmx/src/Main.hx`, in `writeTmx()`, change:

```haxe
    sb.add('  <tileset firstgid="1" name="terrain" tilewidth="8" tileheight="8" tilecount="6"/>\n');
```

to:

```haxe
    sb.add('  <tileset firstgid="1" name="terrain" tilewidth="8" tileheight="8" tilecount="10"/>\n');
```

- [ ] **Step 3: Build worldgen and generate a small test map**

Run:

```bash
./build_native.sh worldgen-tmx
./bin/worldgen-tmx 64 64 /tmp/wg-check.tmx
```

Expected: `wrote /tmp/wg-check.tmx (64 x 64)`.

- [ ] **Step 4: Verify every generated tile id is within 1–10**

Run:

```bash
sed -n '/<data encoding="csv">/,/<\/data>/p' /tmp/wg-check.tmx \
  | tr ',\n' '\n\n' | grep -E '^[0-9]+$' | sort -n | sed -n '1p;$p'
```

Expected: two lines — the minimum and maximum tile id. The minimum must be `>= 1` and the maximum must be `<= 10`.

- [ ] **Step 5: Regenerate the real starter map**

Run: `make regenerate-map`
Expected: `wrote res/maps/starter.tmx (1024 x 1024)`.

- [ ] **Step 6: Verify the regenerated map still parses**

Run: `make test`
Expected: PASS — `TestTmxParser` still green (`starter.tmx` is not its fixture, but this confirms no regression).

- [ ] **Step 7: Commit**

```bash
git add tools/worldgen-tmx/src/Main.hx res/maps/starter.tmx
git commit -m "feat(worldgen): place dirt, flower, lava, cactus tiles

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Client test harness + `SpriteCatalog`

`SpriteCatalog` is **pure data** — no `h2d`/`hxd` imports — so it is unit-testable headlessly. It maps each `TileType` to a terrain sprite cell (`sheet`, `col`, `row`) plus a palette word, and exposes the player palette constant. The cell coordinates and palettes are derived from the legacy tile render code (`engine/src/engine/...` was `src/engine`; the legacy tiles live in `src/game/level/tile/`).

**Files:**
- Create: `client/src/client/render/SpriteCatalog.hx`
- Create: `client/build-client-test.hxml`, `client/test/TestMain.hx`, `client/test/TestSpriteCatalog.hx`
- Modify: `Makefile`, `build_native.sh`, `build_native.ps1`

- [ ] **Step 1: Create `SpriteCatalog`**

Create `client/src/client/render/SpriteCatalog.hx`:

```haxe
package client.render;

import engine.gfx.Color;
import shared.world.TileType;

/** One flat terrain sprite: a grayscale cell on a sheet plus a palette word. */
typedef TileSprite = {
  var sheet:String;
  var col:Int;
  var row:Int;
  var colors:Int;
};

/**
 * Pure mapping data — TileType -> terrain sprite cell + palette.
 *
 * Cells and palettes are lifted from the legacy single-player tile render code:
 *   - Ground tiles use the grayscale 4-quadrant base cell terrain(0,0),
 *     palette-shifted per tile type.
 *   - WATER/ROCK/STONE/LAVA/TREE/CACTUS use their own cells/palettes.
 * Flat per-tile: exactly one cell per tile (no neighbour blending).
 */
class SpriteCatalog {
  // Fixed terrain palette levels (the legacy levels' surface colors).
  static inline var GRASS_C = 141;
  static inline var DIRT_C = 322;
  static inline var SAND_C = 550;

  /** Every TileType, for completeness checks and iteration. */
  public static var ALL_TILES(default, null):Array<TileType> = [
    GRASS, SAND, WATER, STONE, ROCK, TREE, DIRT, FLOWER, LAVA, CACTUS
  ];

  /** TileType (as Int key) -> its flat terrain sprite. */
  public static var TILE_TABLE(default, null):Map<Int, TileSprite> = [
    (GRASS : Int)  => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(GRASS_C, GRASS_C, GRASS_C + 111, GRASS_C + 111) },
    (DIRT : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(DIRT_C, DIRT_C, DIRT_C - 111, DIRT_C - 111) },
    (SAND : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(SAND_C + 2, SAND_C, SAND_C - 110, SAND_C - 110) },
    (FLOWER : Int) => { sheet: "terrain", col: 1, row: 1,
                        colors: Color.get(10, GRASS_C, 555, 440) },
    (WATER : Int)  => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(5, 5, 115, 115) },
    (STONE : Int)  => { sheet: "terrain", col: 0, row: 1,
                        colors: Color.get(111, DIRT_C, 333, 555) },
    (ROCK : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(444, 444, 333, 333) },
    (LAVA : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(500, 500, 520, 550) },
    (TREE : Int)   => { sheet: "terrain", col: 10, row: 1,
                        colors: Color.get(10, 30, 151, GRASS_C) },
    (CACTUS : Int) => { sheet: "terrain", col: 8, row: 2,
                        colors: Color.get(20, 40, 50, SAND_C) },
  ];

  /** Player body palette (legacy Player.render: Color.get(-1,100,220,532)). */
  public static var PLAYER_COLORS(default, null):Int = Color.get(-1, 100, 220, 532);

  /** True if every TileType has a TILE_TABLE entry. */
  public static function isComplete():Bool {
    for (tt in ALL_TILES) {
      if (!TILE_TABLE.exists((tt : Int))) return false;
    }
    return true;
  }
}
```

- [ ] **Step 2: Create the client test harness**

Create `client/build-client-test.hxml`:

```
-cp src
-cp test
-cp ../shared/src
-cp ../engine/src
-lib utest
-main TestMain
--hl ../out/client-test.hl
-D analyzer-optimize
```

Create `client/test/TestMain.hx`:

```haxe
package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestSpriteCatalog());
    Report.create(r);
    r.run();
  }
}
```

Create `client/test/TestSpriteCatalog.hx`:

```haxe
package;

import utest.Test;
import utest.Assert;
import client.render.SpriteCatalog;
import shared.world.TileType;

class TestSpriteCatalog extends Test {
  function testEveryTileTypeHasASprite() {
    Assert.isTrue(SpriteCatalog.isComplete());
  }

  function testAllTilesListCoversIds1To10() {
    Assert.equals(10, SpriteCatalog.ALL_TILES.length);
    for (tt in SpriteCatalog.ALL_TILES) {
      Assert.isTrue(SpriteCatalog.TILE_TABLE.exists((tt : Int)));
    }
  }

  function testTreeCellIsNonZero() {
    var tree = SpriteCatalog.TILE_TABLE.get((TileType.TREE : Int));
    Assert.equals("terrain", tree.sheet);
    Assert.equals(10, tree.col);
  }
}
```

- [ ] **Step 3: Add the `client-test` Makefile target**

In `Makefile`, add `client-test` to the `.PHONY` line, and add this target after the `server-test` target:

```makefile
client-test: out
	cd client && haxe build-client-test.hxml
	hl out/client-test.hl
```

- [ ] **Step 4: Add the `client-test` native build target (bash)**

In `build_native.sh`:

1. In the `ALL=(...)` array, add `client-test`:

```bash
ALL=(worldgen-tmx server-cli gateway zone shared-test server-test client-test client)
```

2. Add a build function after `build_server_test()`:

```bash
build_client_test() {
  echo "[client-test]"
  gen_c client-test client -cp src -cp test -cp ../shared/src -cp ../engine/src \
    -lib utest -main TestMain -D analyzer-optimize
  compile client-test "${SYS_HEADLESS[@]}"
}
```

3. In the dispatch `case` statement, add a branch:

```bash
    client-test)  build_client_test ;;
```

- [ ] **Step 5: Add the `client-test` native build target (PowerShell)**

In `build_native.ps1`:

1. In `$All`, add `client-test`:

```powershell
$All = @('worldgen-tmx','server-cli','gateway','zone','shared-test','server-test','client-test','client')
```

2. Add a build function after `Build-ServerTest`:

```powershell
function Build-ClientTest {
  Write-Host '[client-test]'
  Gen-C 'client-test' 'client' @('-cp','src','-cp','test','-cp','..\shared\src','-cp','..\engine\src','-lib','utest','-main','TestMain','-D','analyzer-optimize')
  Compile-Target 'client-test' @() $HeadlessSys
}
```

3. In the dispatch `switch`, add a branch:

```powershell
    'client-test'  { Build-ClientTest }
```

- [ ] **Step 6: Run the client tests to verify they pass**

Run: `./build_native.sh client-test && ./bin/client-test`
Expected: PASS — `ALL TESTS OK`, 3 `TestSpriteCatalog` cases green.

- [ ] **Step 7: Commit**

```bash
git add client/src/client/render/SpriteCatalog.hx client/build-client-test.hxml client/test Makefile build_native.sh build_native.ps1
git commit -m "feat(client): add SpriteCatalog and a headless client test harness

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `ZoneRenderer` — terrain rendering

`ZoneRenderer` owns the `Screen`/`GpuRenderer`/`SpriteRegistry`. This task implements terrain only; entities still render through the old `EntityRenderer` (colored squares) until Task 7. Sprite sheets are loaded with `sys.io.File` + Heaps' PNG decoder — matching the MMO client's existing `File`-based resource loading (`Main.transitionToInZone` already reads `res/maps/starter.tmx` that way), so `hxd.Res` and `resourcesPath` are not involved.

**Files:**
- Create: `client/src/client/render/ZoneRenderer.hx`
- Modify: `client/src/client/Main.hx`

- [ ] **Step 1: Create `ZoneRenderer` with terrain rendering**

Create `client/src/client/render/ZoneRenderer.hx`:

```haxe
package client.render;

import haxe.io.BytesInput;
import engine.gfx.Screen;
import engine.gfx.GpuRenderer;
import engine.gfx.SpriteRegistry;
import engine.gfx.SpriteSheet;
import engine.gfx.SpriteId;
import shared.world.MapData;

/**
 * Renders the zone into a fixed 320x240 Screen buffer, scaled to the window.
 * Terrain is flat: one palette-shifted sprite per 8x8 tile.
 */
class ZoneRenderer {
  public static inline var SCREEN_W = 320;
  public static inline var SCREEN_H = 240;
  static inline var TILE = 8;

  var screen:Screen;
  var gpu:GpuRenderer;
  var registry:SpriteRegistry;
  var map:MapData;

  // Resolved terrain sprites, keyed by TileType-as-Int.
  var tileSprites:Map<Int, {id:SpriteId, colors:Int}> = new Map();

  public function new(scene:h2d.Scene, map:MapData) {
    this.map = map;
    Screen.initPalette();
    screen = new Screen(SCREEN_W, SCREEN_H);
    gpu = new GpuRenderer(SCREEN_W, SCREEN_H, scene);
    screen.gpu = gpu;
    registry = new SpriteRegistry();
    loadSheets();
    screen.spriteRegistry = registry;
    applyScale();
  }

  /** Decode a PNG from disk into hxd.Pixels (no hxd.Res / resourcesPath). */
  static function loadPixels(path:String):hxd.Pixels {
    var bytes = sys.io.File.getBytes(path);
    var png = new hxd.fmt.png.Reader(new BytesInput(bytes)).read();
    return hxd.fmt.png.Tools.decodePixels(png);
  }

  function loadSheets():Void {
    registry.registerEngineSheet("terrain", new SpriteSheet(loadPixels("res/sprites/sprites_terrain.png")));
    registry.registerEngineSheet("player", new SpriteSheet(loadPixels("res/sprites/sprites_player.png")));

    for (tt in SpriteCatalog.ALL_TILES) {
      var e = SpriteCatalog.TILE_TABLE.get((tt : Int));
      var id = registry.defineSprite("tile_" + (tt : Int), e.sheet, e.col, e.row);
      tileSprites.set((tt : Int), {id: id, colors: e.colors});
    }
  }

  /** Scale the 320x240 Screen up to fill the window (integer-ish scale). */
  public function applyScale():Void {
    var win = hxd.Window.getInstance();
    gpu.setScale(win.width / SCREEN_W, win.height / SCREEN_H);
  }

  public function onResize():Void {
    applyScale();
  }

  /**
   * Draw one frame. `centerTileX/Y` is the tile the camera centers on
   * (the local player's interpolated position).
   */
  public function render(centerTileX:Float, centerTileY:Float):Void {
    gpu.beginFrame();

    var camPxX = centerTileX * TILE + TILE / 2;
    var camPxY = centerTileY * TILE + TILE / 2;
    var xScroll = Std.int(camPxX - SCREEN_W / 2);
    var yScroll = Std.int(camPxY - SCREEN_H / 2);

    var maxX = map.width * TILE - SCREEN_W;
    var maxY = map.height * TILE - SCREEN_H;
    if (xScroll < 0) xScroll = 0; else if (xScroll > maxX) xScroll = maxX;
    if (yScroll < 0) yScroll = 0; else if (yScroll > maxY) yScroll = maxY;
    screen.setOffset(xScroll, yScroll);

    var tx0 = Std.int(xScroll / TILE);
    var ty0 = Std.int(yScroll / TILE);
    var tx1 = tx0 + Std.int(SCREEN_W / TILE) + 1;
    var ty1 = ty0 + Std.int(SCREEN_H / TILE) + 1;

    for (ty in ty0...ty1 + 1) {
      for (tx in tx0...tx1 + 1) {
        var t = map.tileAt(tx, ty);
        var spr = tileSprites.get(t);
        if (spr == null) {
          // Missing-sprite safety: a magenta block.
          drawMissing(tx * TILE, ty * TILE);
          continue;
        }
        screen.renderSprite(tx * TILE, ty * TILE, spr.id, spr.colors, 0, 0);
      }
    }

    endFrame();
  }

  function drawMissing(px:Int, py:Int):Void {
    // Reuse the first terrain cell tinted magenta as a visible placeholder.
    var any = tileSprites.get((shared.world.TileType.GRASS : Int));
    if (any != null) screen.renderSprite(px, py, any.id, 0, 0, 0xFF00FF);
  }

  /** Exposed so Task 7 can draw entities between terrain and endFrame. */
  function endFrame():Void {
    gpu.endFrame();
  }
}
```

- [ ] **Step 2: Wire `ZoneRenderer` into `Main` (terrain only)**

In `client/src/client/Main.hx`:

1. Add an import near the other `client.game` imports:

```haxe
import client.render.ZoneRenderer;
```

2. Add a field next to `worldRenderer`:

```haxe
  var zoneRenderer:ZoneRenderer;
```

3. In `transitionToInZone()`, after the `worldRenderer`/`entityRenderer` setup lines, add:

```haxe
    zoneRenderer = new ZoneRenderer(s2d, map);
```

4. In `transitionToInZone()`, remove the `worldRenderer` creation line:

```haxe
    worldRenderer = new client.game.WorldRenderer(inZoneScreen, map, camera);
```

5. In `update(dt)`, replace the `worldRenderer.redraw();` call. The block currently reads:

```haxe
    if (state == IN_ZONE && worldRenderer != null) {
      worldRenderer.redraw();
      if (entityRenderer != null) entityRenderer.redraw();
      if (inputDispatcher != null) inputDispatcher.update();
    }
```

Change it to:

```haxe
    if (state == IN_ZONE && zoneRenderer != null) {
      zoneRenderer.render(camera.centerWorldX, camera.centerWorldY);
      if (entityRenderer != null) entityRenderer.redraw();
      if (inputDispatcher != null) inputDispatcher.update();
    }
```

6. Add a resize handler. Add this override method to the `Main` class:

```haxe
  override function onResize() {
    if (zoneRenderer != null) zoneRenderer.onResize();
  }
```

(`camera` is still created in `transitionToInZone` and still updated by `onEntityMove` — it is kept as the camera-position holder until Task 7. `worldRenderer` is now unused but its field/import stay until Task 8.)

- [ ] **Step 3: Build the client**

Run: `./build_native.sh client`
Expected: `clang -> bin/client`, exit 0.

- [ ] **Step 4: Eyes-on verification — terrain renders**

Start the server, then the client:

```bash
./run-server.sh        # terminal 1 — wait for "listening on 127.0.0.1:7778"
./run-client.sh        # terminal 2
```

Log in with a test account (`./bin/server-cli create-account tester hunter2` first, if needed).
Expected: after the connecting screen, the world renders as **real terrain sprites** (green grass, blue water, brown dirt, etc.) instead of flat colored rectangles. Your player still appears as a colored square (entity rendering is Task 7). WASD still scrolls the world.

- [ ] **Step 5: Commit**

```bash
git add client/src/client/render/ZoneRenderer.hx client/src/client/Main.hx
git commit -m "feat(client): render terrain through the engine.gfx pipeline

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `ZoneRenderer` — entity & player rendering

This task moves entity rendering into `ZoneRenderer`, drawing every networked player with the original animated player sprite. Facing is derived client-side from each move's delta; a 2-phase walk animation plays during move interpolation.

**Files:**
- Create: `client/src/client/render/EntityVisual.hx`
- Modify: `client/src/client/render/ZoneRenderer.hx`, `client/src/client/Main.hx`

- [ ] **Step 1: Create `EntityVisual`**

Create `client/src/client/render/EntityVisual.hx`. This is the interpolation logic from the old `EntityRenderer`, plus `facing` and a walk phase:

```haxe
package client.render;

import shared.world.Direction;

/** Client-side render state for one networked entity. */
class EntityVisual {
  public var id:Int;
  public var name:String;
  public var fromX:Float = 0;
  public var fromY:Float = 0;
  public var toX:Float = 0;
  public var toY:Float = 0;
  public var moveStartTime:Float = 0;
  public var moveDurationS:Float = 0;
  public var facing:Direction = SOUTH;

  public function new(id:Int, name:String) {
    this.id = id;
    this.name = name;
  }

  public function spawnAt(tileX:Int, tileY:Int):Void {
    fromX = toX = tileX;
    fromY = toY = tileY;
  }

  public function applyMove(toX:Int, toY:Int, durationMs:Int):Void {
    var cur = currentPos();
    var dx = toX - this.toX;
    var dy = toY - this.toY;
    if (dx > 0) facing = EAST;
    else if (dx < 0) facing = WEST;
    else if (dy > 0) facing = SOUTH;
    else if (dy < 0) facing = NORTH;
    fromX = cur.x;
    fromY = cur.y;
    this.toX = toX;
    this.toY = toY;
    moveStartTime = haxe.Timer.stamp();
    moveDurationS = durationMs / 1000.0;
  }

  /** Interpolated tile-space position. */
  public function currentPos():{x:Float, y:Float} {
    if (moveDurationS <= 0) return {x: toX, y: toY};
    var elapsed = haxe.Timer.stamp() - moveStartTime;
    if (elapsed >= moveDurationS) return {x: toX, y: toY};
    var t = elapsed / moveDurationS;
    return {
      x: fromX + (toX - fromX) * t,
      y: fromY + (toY - fromY) * t
    };
  }

  /** True while a move interpolation is in progress. */
  public function isMoving():Bool {
    if (moveDurationS <= 0) return false;
    return (haxe.Timer.stamp() - moveStartTime) < moveDurationS;
  }

  /** 0 or 1 — walk-cycle phase, advances while moving. */
  public function walkPhase():Int {
    if (!isMoving()) return 0;
    var elapsed = haxe.Timer.stamp() - moveStartTime;
    return Std.int(elapsed / (moveDurationS / 2)) % 2;
  }
}
```

- [ ] **Step 2: Add entity rendering to `ZoneRenderer`**

In `client/src/client/render/ZoneRenderer.hx`:

1. Add imports near the top (after the existing imports):

```haxe
import shared.world.Direction;
```

2. Add fields after `tileSprites`:

```haxe
  var entities:Map<Int, EntityVisual> = new Map();
  var ownEntityId:Int = 0;
  // Player body cells: 4 quadrants per (direction, phase), packed SpriteIds.
  var playerSprites:Map<String, Array<SpriteId>> = new Map();
```

3. Change the constructor signature and store `ownEntityId`. Replace:

```haxe
  public function new(scene:h2d.Scene, map:MapData) {
    this.map = map;
```

with:

```haxe
  public function new(scene:h2d.Scene, map:MapData, ownEntityId:Int) {
    this.map = map;
    this.ownEntityId = ownEntityId;
```

4. At the end of `loadSheets()`, after the tile-sprite loop, register the player body cells. The legacy player sheet uses sheet-local rows 0 (top) and 1 (bottom); column offsets: SOUTH=0, NORTH=2, side=4/6:

```haxe
    // Player body: 4 cells (TL,TR,BL,BR) per direction+phase.
    function playerCells(name:String, colBase:Int):Void {
      playerSprites.set(name, [
        registry.defineSprite('p_${name}_tl', "player", colBase,     0),
        registry.defineSprite('p_${name}_tr', "player", colBase + 1, 0),
        registry.defineSprite('p_${name}_bl', "player", colBase,     1),
        registry.defineSprite('p_${name}_br', "player", colBase + 1, 1),
      ]);
    }
    playerCells("south", 0);
    playerCells("north", 2);
    playerCells("side0", 4);
    playerCells("side1", 6);
```

5. Add public entity methods (place them after `render`):

```haxe
  public function spawnEntity(id:Int, name:String, tileX:Int, tileY:Int):Void {
    var v = new EntityVisual(id, name);
    v.spawnAt(tileX, tileY);
    entities.set(id, v);
  }

  public function despawnEntity(id:Int):Void {
    entities.remove(id);
  }

  public function moveEntity(id:Int, toX:Int, toY:Int, durationMs:Int):Void {
    var v = entities.get(id);
    if (v != null) v.applyMove(toX, toY, durationMs);
  }

  /** The local player's interpolated tile position (for camera centering). */
  public function ownPos():{x:Float, y:Float} {
    var v = entities.get(ownEntityId);
    if (v == null) return {x: 0, y: 0};
    return v.currentPos();
  }
```

6. Add the entity-draw routine and call it from `render()`. Insert this call in `render()` immediately before `endFrame();`:

```haxe
    drawEntities();
```

Then add the method:

```haxe
  function drawEntities():Void {
    for (v in entities) {
      var p = v.currentPos();
      var px = Std.int(p.x * TILE) - 4;   // 16px sprite centered on 8px tile
      var py = Std.int(p.y * TILE) - 8;   // anchored so feet sit on the tile

      var name:String;
      var flip:Int = 0;
      switch (v.facing) {
        case SOUTH: name = "south";
        case NORTH: name = "north";
        case EAST:  name = (v.walkPhase() == 0) ? "side0" : "side1";
        case WEST:  name = (v.walkPhase() == 0) ? "side0" : "side1"; flip = 1;
      }
      var cells = playerSprites.get(name);   // [TL, TR, BL, BR]
      var c = SpriteCatalog.PLAYER_COLORS;
      if (flip == 0) {
        screen.renderSprite(px + 0, py + 0, cells[0], c, 0, 0);
        screen.renderSprite(px + 8, py + 0, cells[1], c, 0, 0);
        screen.renderSprite(px + 0, py + 8, cells[2], c, 0, 0);
        screen.renderSprite(px + 8, py + 8, cells[3], c, 0, 0);
      } else {
        // Mirror: the left column shows the mirrored right cell, and vice versa.
        screen.renderSprite(px + 0, py + 0, cells[1], c, 1, 0);
        screen.renderSprite(px + 8, py + 0, cells[0], c, 1, 0);
        screen.renderSprite(px + 0, py + 8, cells[3], c, 1, 0);
        screen.renderSprite(px + 8, py + 8, cells[2], c, 1, 0);
      }
    }
  }
```

- [ ] **Step 3: Wire entities through `ZoneRenderer` in `Main`**

In `client/src/client/Main.hx`:

1. In `transitionToInZone()`, change the `ZoneRenderer` construction to pass `ownEntityId`:

```haxe
    zoneRenderer = new ZoneRenderer(s2d, map, ownEntityId);
```

2. In `transitionToInZone()`, remove the `entityRenderer` creation line:

```haxe
    entityRenderer = new EntityRenderer(inZoneScreen, camera, ownEntityId);
```

3. In `onEntitySpawn()`, replace the body's renderer call:

```haxe
    if (entityRenderer != null) entityRenderer.spawn(m.entityId, m.name, m.tileX, m.tileY);
```

with:

```haxe
    if (zoneRenderer != null) zoneRenderer.spawnEntity(m.entityId, m.name, m.tileX, m.tileY);
```

4. In `onEntityMove()`, replace:

```haxe
    if (entityRenderer != null) entityRenderer.applyMove(m.entityId, m.fromX, m.fromY, m.toX, m.toY, m.durationMs);
```

with:

```haxe
    if (zoneRenderer != null) zoneRenderer.moveEntity(m.entityId, m.toX, m.toY, m.durationMs);
```

5. In `onEntityDespawn()`, replace:

```haxe
    if (entityRenderer != null) entityRenderer.despawn(m.entityId);
```

with:

```haxe
    if (zoneRenderer != null) zoneRenderer.despawnEntity(m.entityId);
```

6. In `update(dt)`, change the render block to center on the local player's interpolated position and drop the old `entityRenderer` call:

```haxe
    if (state == IN_ZONE && zoneRenderer != null) {
      var own = zoneRenderer.ownPos();
      zoneRenderer.render(own.x, own.y);
      if (inputDispatcher != null) inputDispatcher.update();
    }
```

(`camera` and `ownTileX/Y` updates in `onEntityMove` become unused; they are removed in Task 8.)

- [ ] **Step 4: Build the client**

Run: `./build_native.sh client`
Expected: `clang -> bin/client`, exit 0.

- [ ] **Step 5: Eyes-on verification — player sprite renders**

Run the server and client as in Task 6 Step 4.
Expected: your player renders as the **animated pixel-art player sprite** (not a square). Pressing WASD turns the player to face the move direction, and the walk animation plays while moving. A second client (run `./run-client.sh` again with another account) appears as a player sprite too, interpolating smoothly.

- [ ] **Step 6: Commit**

```bash
git add client/src/client/render/EntityVisual.hx client/src/client/render/ZoneRenderer.hx client/src/client/Main.hx
git commit -m "feat(client): render players with the animated sprite + facing

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Remove dead code, write the eyes-on guide, run regression

**Files:**
- Delete: `client/src/client/game/Camera.hx`, `client/src/client/game/WorldRenderer.hx`, `client/src/client/game/EntityRenderer.hx`, `client/src/client/ui/InZoneScreen.hx`
- Modify: `client/src/client/Main.hx`
- Create: `README-SUBPROJECT1.md`

- [ ] **Step 1: Remove the now-unused renderer fields and references in `Main`**

In `client/src/client/Main.hx`:

1. Delete these imports:

```haxe
import client.ui.InZoneScreen;
import client.game.EntityRenderer;
import client.game.Camera;
```

2. Delete these fields:

```haxe
  var inZoneScreen:InZoneScreen;
  var ownTileX:Int = 0;
  var ownTileY:Int = 0;
  var camera:Camera;
  var worldRenderer:client.game.WorldRenderer;
  var entityRenderer:EntityRenderer;
```

3. In `onEnterZoneAck()`, delete the two now-unused assignments:

```haxe
    ownTileX = ack.tileX;
    ownTileY = ack.tileY;
```

4. In `transitionToInZone()`, delete the now-dead lines (the camera setup and the `inZoneScreen` creation):

```haxe
    var win = hxd.Window.getInstance();
    camera = new Camera(16, win.width, win.height);
    camera.centerWorldX = ownTileX;
    camera.centerWorldY = ownTileY;
    inZoneScreen = new InZoneScreen(s2d);
```

5. In `onEntityMove()`, delete the now-dead camera-update block:

```haxe
    if (m.entityId == ownEntityId) {
      ownTileX = m.toX;
      ownTileY = m.toY;
      if (camera != null) {
        camera.centerWorldX = m.toX;
        camera.centerWorldY = m.toY;
      }
    }
```

- [ ] **Step 2: Delete the dead renderer files**

```bash
git rm client/src/client/game/Camera.hx client/src/client/game/WorldRenderer.hx client/src/client/game/EntityRenderer.hx client/src/client/ui/InZoneScreen.hx
```

(`client/src/client/game/InputDispatcher.hx` is still used — do not delete it.)

- [ ] **Step 3: Build the client to confirm nothing references the deleted files**

Run: `./build_native.sh client`
Expected: `clang -> bin/client`, exit 0. (A failure here means a leftover reference — fix it before continuing.)

- [ ] **Step 4: Write the eyes-on test guide**

Create `README-SUBPROJECT1.md`:

```markdown
# Sub-project 1: World Rendering — Eyes-On Test Guide

Manual verification that the MMO client renders the world with real sprites.

## Prereqs

See `README-M0.md`. On Apple Silicon, native binaries are built with
`./build_native.sh` (the `hl` JIT is unavailable on ARM Macs).

## Setup

```bash
./build_native.sh                       # build everything
./bin/server-cli create-account tester hunter2   # if no account yet
```

## Launch

Terminal 1 — server (wait for `listening on 127.0.0.1:7778`):

```bash
./run-server.sh
```

Terminal 2 — client:

```bash
./run-client.sh
```

## What to verify

- [ ] Log in as `tester` / `hunter2`. After the connecting screen, the world
      renders as **real pixel-art terrain** — grass, water, sand, dirt, stone,
      rock, trees, flowers, lava, cactus — not flat colored rectangles.
- [ ] Your player renders as the **animated player sprite**, not a square.
- [ ] WASD / arrow keys move the player one tile per server tick; the player
      **faces the direction of travel** and the **walk animation** plays.
- [ ] The world scrolls to keep the player centered.
- [ ] Open a second client with a second account — both players see each other
      as animated sprites, moving smoothly.

## Notes

- Terrain is flat (one sprite per tile, no neighbour blending) — hard tile
  edges are expected; blending is deferred.
- Lighting is full-bright — no day/night, no light sources.
```

- [ ] **Step 5: Run the full regression suite**

```bash
make test
./build_native.sh client-test && ./bin/client-test
./run-integration.sh
```

Expected:
- `make test` (shared) — `ALL TESTS OK`, includes `TestTileType`.
- `client-test` — `ALL TESTS OK`, `TestSpriteCatalog` green.
- `run-integration.sh` — `ALL TESTS OK`, 77 server-test assertions still pass (no server-authority/protocol change).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(client): remove colored-square renderers; add eyes-on guide

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes

**Spec coverage:**
- §1 Module restructure → Task 1 (move), Task 2 (client classpath). The spec's "break the `game` coupling" item is addressed in the plan header: the coupled files (`Font`, `Engine`) are not on the client's compile graph, so no decoupling is required.
- §2 Client rendering pipeline → Tasks 6–7 (`ZoneRenderer` owns `Screen`/`GpuRenderer`/`SpriteRegistry`; 320×240; `Camera` retired in Task 8); lighting full-bright (no overlay calls made).
- §3 Tile vocabulary → Task 3 (`TileType` 10 types), Task 4 (worldgen + regenerate).
- §4 Sprite catalog & entity rendering → Task 5 (`SpriteCatalog`), Task 7 (player sprite, facing, walk phase, missing-sprite magenta placeholder in Task 6's `drawMissing`).
- §5 Testing & error handling → Task 3 (`TileType` tests), Task 5 (`SpriteCatalog` completeness), Task 4 (worldgen range check), Task 8 (regression + eyes-on guide); missing-sprite safety in `ZoneRenderer.drawMissing`.

**Type consistency:** `ZoneRenderer` constructor is `(scene, map)` in Task 6, changed to `(scene, map, ownEntityId)` in Task 7 — Task 7 Step 1.3 makes the signature change and Task 7 Step 3.1 updates the caller. `SpriteCatalog.TILE_TABLE` is keyed by `Int` throughout; `ALL_TILES` is `Array<TileType>` and callers cast to `Int` for lookups consistently. `EntityVisual.applyMove` takes `(toX, toY, durationMs)` and `ZoneRenderer.moveEntity` calls it with exactly those.

**Out of scope (deferred to later sub-projects):** items, inventory, interactive tiles, crafting, menus, day/night lighting, neighbour-blended terrain.
