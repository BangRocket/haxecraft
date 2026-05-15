package client.game;

import h2d.Object;
import h2d.Graphics;
import shared.world.MapData;

class WorldRenderer extends Object {
  static var COLOR = [
    /* 0 unused */    0xff000000,
    /* GRASS  */      0xff3e8a3e,
    /* SAND   */      0xffd6c585,
    /* WATER  */      0xff2b5cae,
    /* STONE  */      0xff6b6b6b,
    /* ROCK   */      0xff4a4a4a,
    /* TREE   */      0xff224d22
  ];

  var gfx:Graphics;
  var map:MapData;
  var camera:Camera;

  public function new(parent:Object, map:MapData, camera:Camera) {
    super(parent);
    this.map = map;
    this.camera = camera;
    this.gfx = new Graphics(this);
  }

  public function redraw():Void {
    gfx.clear();
    var rect = camera.visibleRect();
    var ts = camera.pixelTileSize;
    for (ty in rect.minY...rect.maxY) {
      for (tx in rect.minX...rect.maxX) {
        var t = map.tileAt(tx, ty);
        if (t < 1 || t >= COLOR.length) continue;
        var color = COLOR[t];
        var px = camera.tileToScreenX(tx);
        var py = camera.tileToScreenY(ty);
        gfx.beginFill(color & 0xffffff, ((color >>> 24) & 0xff) / 255.0);
        gfx.drawRect(px, py, ts, ts);
        gfx.endFill();
      }
    }
  }
}
