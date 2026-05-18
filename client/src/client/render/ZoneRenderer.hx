package client.render;

import engine.gfx.Screen;
import engine.gfx.GpuRenderer;
import engine.gfx.SpriteRegistry;
import engine.gfx.SpriteSheet;
import engine.gfx.SpriteId;
import shared.world.MapData;
import shared.world.Direction;
import shared.item.ItemType;
import shared.item.ItemCategory;

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

  var entities:Map<Int, EntityVisual> = new Map();
  var ownEntityId:Int = 0;
  // Player body cells [TL,TR,BL,BR], keyed by "south"/"north"/"side0"/"side1".
  var playerSprites:Map<String, Array<SpriteId>> = new Map();

  // SP2 static world content. Resources/tools render one 8x8 cell; furniture
  // renders a 2x2 block ([TL,TR,BL,BR]).
  var itemSprites:Map<Int, {id:SpriteId, colors:Int}> = new Map();
  var furnitureSprites:Map<Int, {cells:Array<SpriteId>, colors:Int}> = new Map();
  var groundItems:Array<GroundItemVisual> = [];
  var worldObjects:Array<{id:Int, typeId:Int, tileX:Int, tileY:Int}> = [];

  public function new(scene:h2d.Scene, map:MapData, ownEntityId:Int) {
    this.map = map;
    this.ownEntityId = ownEntityId;
    // Default to a clean 4x window (1280x960). The scene scaleMode below makes
    // this purely cosmetic — rendering fills whatever size the window is.
    hxd.Window.getInstance().resize(SCREEN_W * 4, SCREEN_H * 4);
    // Render in 320x240 logical space; Heaps stretches the whole scene to fill
    // the window. One scene-level transform => no inter-tile seams, edge to
    // edge at any window size (exactly 4x at the 1280x960 default).
    scene.scaleMode = h2d.Scene.ScaleMode.Stretch(SCREEN_W, SCREEN_H);
    Screen.initPalette();
    screen = new Screen(SCREEN_W, SCREEN_H);
    gpu = new GpuRenderer(SCREEN_W, SCREEN_H, scene);
    screen.gpu = gpu;
    registry = new SpriteRegistry();
    loadSheets();
    screen.spriteRegistry = registry;
  }

  /** Decode a PNG from disk into hxd.Pixels (no hxd.Res / resourcesPath). */
  static function loadPixels(path:String):hxd.Pixels {
    var bytes = sys.io.File.getBytes(path);
    return hxd.res.Any.fromBytes(path, bytes).toImage().getPixels();
  }

  function loadSheets():Void {
    registry.registerEngineSheet("terrain", new SpriteSheet(loadPixels("res/sprites/sprites_terrain.png")));
    registry.registerEngineSheet("player", new SpriteSheet(loadPixels("res/sprites/sprites_player.png")));

    for (tt in SpriteCatalog.ALL_TILES) {
      var e = SpriteCatalog.TILE_TABLE.get((tt : Int));
      var id = registry.defineSprite("tile_" + (tt : Int), e.sheet, e.col, e.row);
      tileSprites.set((tt : Int), {id: id, colors: e.colors});
    }

    // Player body: 4 cells (TL,TR,BL,BR) per direction+phase. The legacy
    // player sheet uses sheet-local rows 0 (top) and 1 (bottom); column
    // offsets: SOUTH=0, NORTH=2, side walk frames at 4 and 6.
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

    // SP2: item & furniture sprites.
    registry.registerEngineSheet("items", new SpriteSheet(loadPixels("res/sprites/sprites_items.png")));
    for (it in SpriteCatalog.ALL_ITEMS) {
      var e = SpriteCatalog.ITEM_TABLE.get((it : Int));
      if (e == null) continue;
      var key:Int = it;
      if (it.category() == ItemCategory.FURNITURE) {
        furnitureSprites.set(key, { colors: e.colors, cells: [
          registry.defineSprite('obj_${key}_tl', e.sheet, e.col,     e.row),
          registry.defineSprite('obj_${key}_tr', e.sheet, e.col + 1, e.row),
          registry.defineSprite('obj_${key}_bl', e.sheet, e.col,     e.row + 1),
          registry.defineSprite('obj_${key}_br', e.sheet, e.col + 1, e.row + 1),
        ]});
      } else {
        itemSprites.set(key,
          { id: registry.defineSprite('item_${key}', e.sheet, e.col, e.row), colors: e.colors });
      }
    }
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

    drawGroundItems();
    drawWorldObjects();
    drawEntities();
    endFrame();
  }

  public function addGroundItem(id:Int, itemTypeId:Int, count:Int, tileX:Int, tileY:Int):Void {
    groundItems.push(new GroundItemVisual(id, itemTypeId, count, tileX, tileY));
  }

  public function addWorldObject(id:Int, objectTypeId:Int, tileX:Int, tileY:Int):Void {
    worldObjects.push({ id: id, typeId: objectTypeId, tileX: tileX, tileY: tileY });
  }

  /** Ground items: one flat 8x8 cell sitting on the tile. */
  function drawGroundItems():Void {
    for (gi in groundItems) {
      var spr = itemSprites.get((gi.itemType : Int));
      if (spr == null) {
        drawMissing(gi.tileX * TILE, gi.tileY * TILE);
        continue;
      }
      screen.renderSprite(gi.tileX * TILE, gi.tileY * TILE, spr.id, spr.colors, 0, 0);
    }
  }

  /** World objects: a 2x2 (16x16) furniture block, anchored like a player. */
  function drawWorldObjects():Void {
    for (o in worldObjects) {
      var px = o.tileX * TILE - 4;
      var py = o.tileY * TILE - 8;
      var f = furnitureSprites.get(o.typeId);
      if (f == null) {
        drawMissing(o.tileX * TILE, o.tileY * TILE);
        continue;
      }
      screen.renderSprite(px + 0, py + 0, f.cells[0], f.colors, 0, 0);
      screen.renderSprite(px + 8, py + 0, f.cells[1], f.colors, 0, 0);
      screen.renderSprite(px + 0, py + 8, f.cells[2], f.colors, 0, 0);
      screen.renderSprite(px + 8, py + 8, f.cells[3], f.colors, 0, 0);
    }
  }

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
