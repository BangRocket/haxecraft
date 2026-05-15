package client.game;

class Camera {
  public var pixelTileSize:Int;
  public var viewportWidth:Int;
  public var viewportHeight:Int;
  public var centerWorldX:Float;
  public var centerWorldY:Float;

  public function new(pixelTileSize:Int, viewportWidth:Int, viewportHeight:Int) {
    this.pixelTileSize = pixelTileSize;
    this.viewportWidth = viewportWidth;
    this.viewportHeight = viewportHeight;
    this.centerWorldX = 0;
    this.centerWorldY = 0;
  }

  public inline function tileToScreenX(tx:Float):Float {
    return (tx - centerWorldX) * pixelTileSize + viewportWidth / 2;
  }
  public inline function tileToScreenY(ty:Float):Float {
    return (ty - centerWorldY) * pixelTileSize + viewportHeight / 2;
  }

  public function visibleRect():{minX:Int, minY:Int, maxX:Int, maxY:Int} {
    var halfW = Math.ceil(viewportWidth / (2 * pixelTileSize)) + 1;
    var halfH = Math.ceil(viewportHeight / (2 * pixelTileSize)) + 1;
    return {
      minX: Math.floor(centerWorldX) - halfW,
      minY: Math.floor(centerWorldY) - halfH,
      maxX: Math.floor(centerWorldX) + halfW + 1,
      maxY: Math.floor(centerWorldY) + halfH + 1
    };
  }
}
