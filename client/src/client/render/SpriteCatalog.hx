package client.render;

import engine.gfx.Color;
import shared.world.TileType;
import shared.item.ItemType;

/** One flat sprite: a grayscale cell on a sheet plus a palette word. */
typedef TileSprite = {
  var sheet:String;
  var col:Int;
  var row:Int;
  var colors:Int;
};

/**
 * Pure mapping data — TileType -> terrain sprite, ItemType -> item sprite.
 *
 * Cells and palettes are lifted from the legacy single-player render code.
 * Flat per-tile: exactly one cell per tile (no neighbour blending).
 *
 * NOTE: TileType and ItemType share several member names (STONE, SAND, ...),
 * so every enum member here is fully qualified — unqualified names would
 * resolve to whichever enum was imported last.
 */
class SpriteCatalog {
  // Fixed terrain palette levels (the legacy levels' surface colors).
  static inline var GRASS_C = 141;
  static inline var DIRT_C = 322;
  static inline var SAND_C = 550;

  /** Every TileType, for completeness checks and iteration. */
  public static var ALL_TILES(default, null):Array<TileType> = [
    TileType.GRASS, TileType.SAND, TileType.WATER, TileType.STONE,
    TileType.ROCK, TileType.TREE, TileType.DIRT, TileType.FLOWER,
    TileType.LAVA, TileType.CACTUS,
    TileType.IRON_ORE, TileType.GOLD_ORE, TileType.GEM_ORE, TileType.HARD_ROCK,
    TileType.FARMLAND, TileType.WHEAT, TileType.TREE_SAPLING,
    TileType.CACTUS_SAPLING, TileType.HOLE
  ];

  /** TileType (as Int key) -> its flat terrain sprite. */
  public static var TILE_TABLE(default, null):Map<Int, TileSprite> = [
    (TileType.GRASS : Int)  => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(GRASS_C, GRASS_C, GRASS_C + 111, GRASS_C + 111) },
    (TileType.DIRT : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(DIRT_C, DIRT_C, DIRT_C - 111, DIRT_C - 111) },
    (TileType.SAND : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(SAND_C + 2, SAND_C, SAND_C - 110, SAND_C - 110) },
    (TileType.FLOWER : Int) => { sheet: "terrain", col: 1, row: 1,
                        colors: Color.get(10, GRASS_C, 555, 440) },
    (TileType.WATER : Int)  => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(5, 5, 115, 115) },
    (TileType.STONE : Int)  => { sheet: "terrain", col: 0, row: 1,
                        colors: Color.get(111, DIRT_C, 333, 555) },
    (TileType.ROCK : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(444, 444, 333, 333) },
    (TileType.LAVA : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(500, 500, 520, 550) },
    // TREE base is just grass — the 16x16 canopy/trunk is rendered as an
    // overlay (see TREE_OVERLAY_CELLS + ZoneRenderer.drawTrees).
    (TileType.TREE : Int)   => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(GRASS_C, GRASS_C, GRASS_C + 111, GRASS_C + 111) },
    (TileType.CACTUS : Int) => { sheet: "terrain", col: 8, row: 2,
                        colors: Color.get(20, 40, 50, SAND_C) },
    // SP4 interactive tiles. Cells reuse known-good terrain cells with
    // distinct palettes (art-matching refinement is a one-line change).
    (TileType.IRON_ORE : Int)  => { sheet: "terrain", col: 0, row: 1,
                        colors: Color.get(111, 222, 433, 544) },
    (TileType.GOLD_ORE : Int)  => { sheet: "terrain", col: 0, row: 1,
                        colors: Color.get(111, 222, 540, 553) },
    (TileType.GEM_ORE : Int)   => { sheet: "terrain", col: 0, row: 1,
                        colors: Color.get(111, 222, 405, 535) },
    (TileType.HARD_ROCK : Int) => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(111, 111, 222, 222) },
    (TileType.FARMLAND : Int)  => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(210, 210, 321, 321) },
    (TileType.WHEAT : Int)     => { sheet: "terrain", col: 1, row: 1,
                        colors: Color.get(210, 231, 552, 540) },
    // Sapling renders as grass-with-flower until a proper sapling cell exists.
    (TileType.TREE_SAPLING : Int) => { sheet: "terrain", col: 1, row: 1,
                        colors: Color.get(10, GRASS_C, 350, 141) },
    (TileType.CACTUS_SAPLING : Int) => { sheet: "terrain", col: 8, row: 2,
                        colors: Color.get(20, 40, 50, 550) },
    (TileType.HOLE : Int)      => { sheet: "terrain", col: 0, row: 0,
                        colors: Color.get(0, 0, 111, 111) },
  ];

  /** Player body palette (legacy Player.render: Color.get(-1,100,220,532)). */
  public static var PLAYER_COLORS(default, null):Int = Color.get(-1, 100, 220, 532);

  /**
   * Tree overlay cells — 4 x 8x8 cells composing the 16x16 canopy+trunk
   * drawn over each TREE tile, ported from legacy TreeTile.render.
   *
   * Per quadrant (TL, TR, BL, BR) there are two variants:
   *   - EDGE: the quadrant faces away from same-type neighbours (forest edge
   *     or standalone tree) — shows canopy/leaves/trunk silhouette.
   *   - INTERIOR: the quadrant faces into a same-type cluster (all three
   *     relevant neighbours are TREE) — shows the interior trunk-seam pattern.
   *
   * ZoneRenderer.drawTrees picks edge vs interior per quadrant from 8 neighbour
   * checks. Cells live on the terrain sheet; palettes use grass as background.
   */
  public static var TREE_OVERLAY_EDGE_CELLS(default, null):Array<TileSprite> = [
    // TL: LEAVES_TOP @ (9,0), foliage palette
    { sheet: "terrain", col: 9,  row: 0, colors: Color.get(10, 30, 151, GRASS_C) },
    // TR: CANOPY_TR  @ (10,0), foliage palette
    { sheet: "terrain", col: 10, row: 0, colors: Color.get(10, 30, 151, GRASS_C) },
    // BL: LEAVES_BL  @ (9,1), bark1 palette (lighter bark/leaves blend)
    { sheet: "terrain", col: 9,  row: 1, colors: Color.get(10, 30, 430, GRASS_C) },
    // BR: TRUNK_BR   @ (10,3), bark2 palette (darker bark)
    { sheet: "terrain", col: 10, row: 3, colors: Color.get(10, 30, 320, GRASS_C) },
  ];

  public static var TREE_OVERLAY_INTERIOR_CELLS(default, null):Array<TileSprite> = [
    // TL: LEAVES_FULL @ (10,1), foliage palette
    { sheet: "terrain", col: 10, row: 1, colors: Color.get(10, 30, 151, GRASS_C) },
    // TR: TRUNK       @ (10,2), bark2 palette
    { sheet: "terrain", col: 10, row: 2, colors: Color.get(10, 30, 320, GRASS_C) },
    // BL: TRUNK       @ (10,2), bark2 palette
    { sheet: "terrain", col: 10, row: 2, colors: Color.get(10, 30, 320, GRASS_C) },
    // BR: LEAVES_FULL @ (10,1), foliage palette
    { sheet: "terrain", col: 10, row: 1, colors: Color.get(10, 30, 151, GRASS_C) },
  ];

  /**
   * The "back-tree fill" cell: a uniformly solid 8x8 foliage cell with zero
   * trunk pixels. (10,1) LEAVES_FULL bleeds trunk pattern through; (12,1) at
   * the centre of the big-tree shape is fully solid mid-gray and is the
   * intended fill for occluded back-tree quadrants.
   */
  public static var TREE_OVERLAY_BACK_CELL(default, null):TileSprite =
    { sheet: "terrain", col: 12, row: 1, colors: Color.get(10, 30, 151, GRASS_C) };

  /** True if every TileType has a TILE_TABLE entry. */
  public static function isComplete():Bool {
    for (tt in ALL_TILES) {
      if (!TILE_TABLE.exists((tt : Int))) return false;
    }
    return true;
  }

  // --- Items & world objects (SP2) ---

  /** Every catalog ItemType, for completeness checks and iteration. */
  public static var ALL_ITEMS(default, null):Array<ItemType> = ItemType.ALL;

  /**
   * ItemType (as Int key) -> its sprite cell + palette.
   *   - Resources: items sheet row 0, one column each.
   *   - Tools: items sheet row 1, one column per tool type, palette per tier.
   *   - Furniture: terrain sheet row 8; the entry is the top-left cell of a
   *     2x2 block (ZoneRenderer expands it).
   * Cells/palettes are lifted from the legacy Resource / ToolItem / Furniture
   * render code — see design §Risks (a manual art-matching step).
   */
  public static var ITEM_TABLE(default, null):Map<Int, TileSprite> = buildItemTable();

  static function buildItemTable():Map<Int, TileSprite> {
    var m = new Map<Int, TileSprite>();

    inline function res(it:ItemType, col:Int, colors:Int):Void {
      m.set((it : Int), { sheet: "items", col: col, row: 0, colors: colors });
    }
    res(ItemType.WOOD, 1, Color.get(-1, 200, 531, 430));
    res(ItemType.STONE, 2, Color.get(-1, 111, 333, 555));
    res(ItemType.FLOWER, 0, Color.get(-1, 10, 444, 330));
    res(ItemType.ACORN, 3, Color.get(-1, 100, 531, 320));
    res(ItemType.DIRT, 2, Color.get(-1, 100, 322, 432));
    res(ItemType.SAND, 2, Color.get(-1, 110, 440, 550));
    res(ItemType.CACTUS, 4, Color.get(-1, 10, 40, 50));
    res(ItemType.SEEDS, 5, Color.get(-1, 10, 40, 50));
    res(ItemType.WHEAT, 6, Color.get(-1, 110, 330, 550));
    res(ItemType.BREAD, 8, Color.get(-1, 110, 330, 550));
    res(ItemType.APPLE, 9, Color.get(-1, 100, 300, 500));
    res(ItemType.COAL, 10, Color.get(-1, 0, 111, 111));
    res(ItemType.IRON_ORE, 10, Color.get(-1, 100, 322, 544));
    res(ItemType.GOLD_ORE, 10, Color.get(-1, 110, 440, 553));
    res(ItemType.IRON_INGOT, 11, Color.get(-1, 100, 322, 544));
    res(ItemType.GOLD_INGOT, 11, Color.get(-1, 110, 330, 553));
    res(ItemType.SLIME, 10, Color.get(-1, 10, 30, 50));
    res(ItemType.GLASS, 12, Color.get(-1, 555, 555, 555));
    res(ItemType.CLOTH, 1, Color.get(-1, 25, 252, 141));
    res(ItemType.CLOUD, 2, Color.get(-1, 222, 555, 444));
    res(ItemType.GEM, 13, Color.get(-1, 101, 404, 545));

    // Tools: row 1, column = tool type (shovel,hoe,sword,pickaxe,axe),
    // palette = material tier (wood,rock,iron,gold,gem). Ids 30..54.
    var tierColors = [
      Color.get(-1, 100, 321, 431), Color.get(-1, 100, 321, 111),
      Color.get(-1, 100, 321, 555), Color.get(-1, 100, 321, 550),
      Color.get(-1, 100, 321, 45),
    ];
    for (i in 0...25) {
      m.set(30 + i, {
        sheet: "items", col: Std.int(i / 5), row: 1, colors: tierColors[i % 5]
      });
    }

    // Furniture: terrain sheet row 8, 2x2 block; TL cell at col = spriteIdx*2.
    inline function furn(it:ItemType, spriteIdx:Int, colors:Int):Void {
      m.set((it : Int), { sheet: "terrain", col: spriteIdx * 2, row: 8, colors: colors });
    }
    furn(ItemType.ANVIL, 0, Color.get(-1, 0, 111, 222));
    furn(ItemType.CHEST, 1, Color.get(-1, 110, 331, 552));
    furn(ItemType.OVEN, 2, Color.get(-1, 0, 332, 442));
    furn(ItemType.FURNACE, 3, Color.get(-1, 0, 222, 333));
    furn(ItemType.WORKBENCH, 4, Color.get(-1, 100, 321, 431));
    furn(ItemType.LANTERN, 5, Color.get(-1, 0, 111, 555));

    return m;
  }

  /** True if every ItemType has an ITEM_TABLE entry. */
  public static function itemsComplete():Bool {
    for (it in ALL_ITEMS) {
      if (!ITEM_TABLE.exists((it : Int))) return false;
    }
    return true;
  }
}
