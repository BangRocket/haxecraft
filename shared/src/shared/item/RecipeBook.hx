package shared.item;

/**
 * The full legacy crafting recipe set as data — 35 recipes across four
 * stations. Enum members are fully qualified: CraftStation and ItemType
 * both define WORKBENCH / FURNACE / etc.
 */
class RecipeBook {
  public static var ALL(default, null):Array<Recipe> = build();

  static inline function stk(t:ItemType, c:Int):RecipeInput {
    return { itemType: t, count: c };
  }

  static function build():Array<Recipe> {
    var list:Array<Recipe> = [];
    var id = 1;
    inline function add(station:CraftStation, output:ItemType, outCount:Int,
        inputs:Array<RecipeInput>):Void {
      list.push(new Recipe(id++, station, output, outCount, inputs));
    }

    // --- Workbench: furniture ---
    add(CraftStation.WORKBENCH, ItemType.WORKBENCH, 1, [stk(ItemType.WOOD, 20)]);
    add(CraftStation.WORKBENCH, ItemType.CHEST, 1, [stk(ItemType.WOOD, 20)]);
    add(CraftStation.WORKBENCH, ItemType.OVEN, 1, [stk(ItemType.STONE, 15)]);
    add(CraftStation.WORKBENCH, ItemType.FURNACE, 1, [stk(ItemType.STONE, 20)]);
    add(CraftStation.WORKBENCH, ItemType.ANVIL, 1, [stk(ItemType.IRON_INGOT, 5)]);
    add(CraftStation.WORKBENCH, ItemType.LANTERN, 1,
      [stk(ItemType.WOOD, 5), stk(ItemType.SLIME, 10), stk(ItemType.GLASS, 4)]);

    // --- Tools: 5 types x 5 tiers. Wood/rock at the workbench, iron/gold/gem
    //     at the anvil. Tool ItemType id = 30 + typeIndex*5 + tier. ---
    for (typeIdx in 0...5) {
      for (tier in 0...5) {
        var tool:ItemType = 30 + typeIdx * 5 + tier;
        var station = (tier <= 1) ? CraftStation.WORKBENCH : CraftStation.ANVIL;
        var inputs = switch tier {
          case 0: [stk(ItemType.WOOD, 5)];
          case 1: [stk(ItemType.WOOD, 5), stk(ItemType.STONE, 5)];
          case 2: [stk(ItemType.WOOD, 5), stk(ItemType.IRON_INGOT, 5)];
          case 3: [stk(ItemType.WOOD, 5), stk(ItemType.GOLD_INGOT, 5)];
          default: [stk(ItemType.WOOD, 5), stk(ItemType.GEM, 50)];
        };
        add(station, tool, 1, inputs);
      }
    }

    // --- Furnace: smelting ---
    add(CraftStation.FURNACE, ItemType.IRON_INGOT, 1,
      [stk(ItemType.IRON_ORE, 4), stk(ItemType.COAL, 1)]);
    add(CraftStation.FURNACE, ItemType.GOLD_INGOT, 1,
      [stk(ItemType.GOLD_ORE, 4), stk(ItemType.COAL, 1)]);
    add(CraftStation.FURNACE, ItemType.GLASS, 1,
      [stk(ItemType.SAND, 4), stk(ItemType.COAL, 1)]);

    // --- Oven: cooking ---
    add(CraftStation.OVEN, ItemType.BREAD, 1, [stk(ItemType.WHEAT, 4)]);

    return list;
  }

  public static function byId(id:Int):Null<Recipe> {
    for (r in ALL) if (r.id == id) return r;
    return null;
  }

  public static function forStation(station:CraftStation):Array<Recipe> {
    return [for (r in ALL) if (r.station == station) r];
  }
}
