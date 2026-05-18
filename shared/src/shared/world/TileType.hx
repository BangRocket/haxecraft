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
  // SP4 interactive tiles
  var IRON_ORE = 11;
  var GOLD_ORE = 12;
  var GEM_ORE = 13;
  var HARD_ROCK = 14;
  var FARMLAND = 15;
  var WHEAT = 16;
  var TREE_SAPLING = 17;
  var CACTUS_SAPLING = 18;
  var HOLE = 19;

  public inline function isWalkable():Bool {
    return switch (cast this : TileType) {
      case GRASS | SAND | DIRT | FLOWER | FARMLAND | WHEAT | HOLE
         | TREE_SAPLING | CACTUS_SAPLING: true;
      case WATER | STONE | ROCK | TREE | LAVA | CACTUS
         | IRON_ORE | GOLD_ORE | GEM_ORE | HARD_ROCK: false;
      default: false;
    }
  }
}
