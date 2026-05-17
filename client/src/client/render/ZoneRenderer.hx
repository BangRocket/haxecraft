package client.render;

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
  }

  /** Scale the 320x240 Screen up to fill the window. */
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
