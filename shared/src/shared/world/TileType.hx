package shared.world;

enum abstract TileType(Int) to Int from Int {
  var GRASS = 1;
  var SAND = 2;
  var WATER = 3;
  var STONE = 4;
  var ROCK = 5;
  var TREE = 6;

  public inline function isWalkable():Bool {
    return switch (cast this : TileType) {
      case GRASS | SAND | STONE: true;
      case WATER | ROCK | TREE: false;
      default: false;
    }
  }
}
