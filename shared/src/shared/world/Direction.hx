package shared.world;

enum abstract Direction(Int) to Int from Int {
  var NORTH = 0;
  var EAST = 1;
  var SOUTH = 2;
  var WEST = 3;

  public inline function dx():Int {
    return switch (cast this : Direction) {
      case EAST: 1;
      case WEST: -1;
      default: 0;
    }
  }

  public inline function dy():Int {
    return switch (cast this : Direction) {
      case NORTH: -1;
      case SOUTH: 1;
      default: 0;
    }
  }
}
