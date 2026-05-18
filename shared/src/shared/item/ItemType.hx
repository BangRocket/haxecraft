package shared.item;

/**
 * The item catalog — every item the game knows about, as pure data.
 *
 * Ids are stable and cross the wire. They are grouped with gaps so later
 * sub-projects can extend a group without renumbering:
 *   resources  1..21
 *   tools     30..54  (5 ToolTypes x 5 material tiers)
 *   furniture 60..65
 *
 * This is identity + classification only. Behaviour (tool damage, food
 * healing, plantable target tiles, recipes) belongs to the sub-projects that
 * consume it. `shared.item` depends on nothing.
 */
enum abstract ItemType(Int) to Int from Int {
  // --- Resources (1..21) ---
  var WOOD = 1;
  var STONE = 2;
  var FLOWER = 3;
  var ACORN = 4;
  var DIRT = 5;
  var SAND = 6;
  var CACTUS = 7;
  var SEEDS = 8;
  var WHEAT = 9;
  var BREAD = 10;
  var APPLE = 11;
  var COAL = 12;
  var IRON_ORE = 13;
  var GOLD_ORE = 14;
  var IRON_INGOT = 15;
  var GOLD_INGOT = 16;
  var SLIME = 17;
  var GLASS = 18;
  var CLOTH = 19;
  var CLOUD = 20;
  var GEM = 21;

  // --- Tools (30..54): tier-minor within type-major order ---
  var WOOD_SHOVEL = 30;
  var ROCK_SHOVEL = 31;
  var IRON_SHOVEL = 32;
  var GOLD_SHOVEL = 33;
  var GEM_SHOVEL = 34;
  var WOOD_HOE = 35;
  var ROCK_HOE = 36;
  var IRON_HOE = 37;
  var GOLD_HOE = 38;
  var GEM_HOE = 39;
  var WOOD_SWORD = 40;
  var ROCK_SWORD = 41;
  var IRON_SWORD = 42;
  var GOLD_SWORD = 43;
  var GEM_SWORD = 44;
  var WOOD_PICKAXE = 45;
  var ROCK_PICKAXE = 46;
  var IRON_PICKAXE = 47;
  var GOLD_PICKAXE = 48;
  var GEM_PICKAXE = 49;
  var WOOD_AXE = 50;
  var ROCK_AXE = 51;
  var IRON_AXE = 52;
  var GOLD_AXE = 53;
  var GEM_AXE = 54;

  // --- Furniture (60..65) ---
  var WORKBENCH = 60;
  var FURNACE = 61;
  var OVEN = 62;
  var ANVIL = 63;
  var CHEST = 64;
  var LANTERN = 65;

  /** Catalog classification, derived from the id range. */
  public function category():ItemCategory {
    var id:Int = this;
    if (id >= 60) return FURNITURE;
    if (id >= 30) return TOOL;
    return RESOURCE;
  }

  /** Resources stack; tools and furniture are individual. */
  public function stackable():Bool {
    return category() == RESOURCE;
  }

  /** Human-readable name. Tool names are composed from tier + type. */
  public function name():String {
    var id:Int = this;
    if (id >= 30 && id <= 54) {
      var idx = id - 30;
      return TOOL_TIERS[idx % 5] + " " + TOOL_TYPES[Std.int(idx / 5)];
    }
    return NAMES.exists(id) ? NAMES.get(id) : 'item#$id';
  }

  /** Tool kind: 0=shovel, 1=hoe, 2=sword, 3=pickaxe, 4=axe; -1 if not a tool. */
  public function toolKind():Int {
    var id:Int = this;
    if (id < 30 || id > 54) return -1;
    return Std.int((id - 30) / 5);
  }

  /** Material tier: 0=wood, 1=rock, 2=iron, 3=gold, 4=gem; -1 if not a tool. */
  public function toolTier():Int {
    var id:Int = this;
    if (id < 30 || id > 54) return -1;
    return (id - 30) % 5;
  }

  static var TOOL_TIERS:Array<String> = ["Wood", "Rock", "Iron", "Gold", "Gem"];
  static var TOOL_TYPES:Array<String> = ["Shovel", "Hoe", "Sword", "Pickaxe", "Axe"];

  static var NAMES:Map<Int, String> = [
    (WOOD : Int) => "Wood", (STONE : Int) => "Stone", (FLOWER : Int) => "Flower",
    (ACORN : Int) => "Acorn", (DIRT : Int) => "Dirt", (SAND : Int) => "Sand",
    (CACTUS : Int) => "Cactus", (SEEDS : Int) => "Seeds", (WHEAT : Int) => "Wheat",
    (BREAD : Int) => "Bread", (APPLE : Int) => "Apple", (COAL : Int) => "Coal",
    (IRON_ORE : Int) => "Iron Ore", (GOLD_ORE : Int) => "Gold Ore",
    (IRON_INGOT : Int) => "Iron Ingot", (GOLD_INGOT : Int) => "Gold Ingot",
    (SLIME : Int) => "Slime", (GLASS : Int) => "Glass", (CLOTH : Int) => "Cloth",
    (CLOUD : Int) => "Cloud", (GEM : Int) => "Gem",
    (WORKBENCH : Int) => "Workbench", (FURNACE : Int) => "Furnace",
    (OVEN : Int) => "Oven", (ANVIL : Int) => "Anvil", (CHEST : Int) => "Chest",
    (LANTERN : Int) => "Lantern",
  ];

  /** Every catalog member, in id order. */
  public static var ALL(default, null):Array<ItemType> = [
    WOOD, STONE, FLOWER, ACORN, DIRT, SAND, CACTUS, SEEDS, WHEAT, BREAD, APPLE,
    COAL, IRON_ORE, GOLD_ORE, IRON_INGOT, GOLD_INGOT, SLIME, GLASS, CLOTH,
    CLOUD, GEM,
    WOOD_SHOVEL, ROCK_SHOVEL, IRON_SHOVEL, GOLD_SHOVEL, GEM_SHOVEL,
    WOOD_HOE, ROCK_HOE, IRON_HOE, GOLD_HOE, GEM_HOE,
    WOOD_SWORD, ROCK_SWORD, IRON_SWORD, GOLD_SWORD, GEM_SWORD,
    WOOD_PICKAXE, ROCK_PICKAXE, IRON_PICKAXE, GOLD_PICKAXE, GEM_PICKAXE,
    WOOD_AXE, ROCK_AXE, IRON_AXE, GOLD_AXE, GEM_AXE,
    WORKBENCH, FURNACE, OVEN, ANVIL, CHEST, LANTERN,
  ];
}
