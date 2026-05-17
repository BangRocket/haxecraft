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
