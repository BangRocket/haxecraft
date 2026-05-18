package server.zone;

import shared.world.TileType;
import shared.item.ItemType;

/**
 * Server-side tile gathering rules — legacy parity, minus stamina.
 * Using the active item on a tile chops/mines/digs/plants it: the tile
 * mutates, drops spawn as ground items. Tool tier scales mined damage.
 */
class TileInteraction {
  static inline var SHOVEL = 0;
  static inline var HOE = 1;
  static inline var SWORD = 2;
  static inline var PICKAXE = 3;
  static inline var AXE = 4;

  /** Apply the actor's active item to (tx, ty). Returns true if something
      happened (the caller then broadcasts the pending tile/item events). */
  public static function apply(sim:ZoneSimulator, ch:Character, tx:Int, ty:Int):Bool {
    var stack = ch.inventory.activeItem();
    if (stack == null) return false;
    var item:ItemType = stack.itemType;
    var tile:Int = sim.map.tileAt(tx, ty);
    var data:Int = sim.map.tileData(tx, ty);

    if (tryPlant(sim, ch, item, tx, ty, tile)) return true;

    var kind = item.toolKind();
    var tier = item.toolTier();
    if (kind < 0) return false;  // the active item is not a tool

    // --- Chopping / mining: damage accumulates in the tile-data byte ---
    if (tile == (TileType.TREE : Int) && kind == AXE) {
      if (Std.random(10) == 0) sim.spawnGroundItem(ItemType.APPLE, 1, tx, ty);
      return accumDamage(sim, tx, ty, data, 10 + tier * 5 + Std.random(10), 20, TileType.GRASS,
        [{ t: ItemType.WOOD, c: 1 + Std.random(2) }, { t: ItemType.ACORN, c: Std.random(4) }]);
    }
    if (tile == (TileType.ROCK : Int) && kind == PICKAXE) {
      return accumDamage(sim, tx, ty, data, 10 + tier * 5 + Std.random(10), 50, TileType.DIRT,
        [{ t: ItemType.STONE, c: 1 + Std.random(4) }, { t: ItemType.COAL, c: Std.random(2) }]);
    }
    if (tile == (TileType.HARD_ROCK : Int) && kind == PICKAXE && tier == 4) {
      return accumDamage(sim, tx, ty, data, 10 + tier * 5 + Std.random(10), 200, TileType.DIRT,
        [{ t: ItemType.STONE, c: 1 + Std.random(4) }, { t: ItemType.COAL, c: Std.random(2) }]);
    }
    if (tile == (TileType.IRON_ORE : Int) && kind == PICKAXE) {
      return accumDamage(sim, tx, ty, data, 1, 3, TileType.DIRT,
        [{ t: ItemType.IRON_ORE, c: 2 + Std.random(2) }]);
    }
    if (tile == (TileType.GOLD_ORE : Int) && kind == PICKAXE) {
      return accumDamage(sim, tx, ty, data, 1, 3, TileType.DIRT,
        [{ t: ItemType.GOLD_ORE, c: 2 + Std.random(2) }]);
    }
    if (tile == (TileType.GEM_ORE : Int) && kind == PICKAXE) {
      return accumDamage(sim, tx, ty, data, 1, 3, TileType.DIRT,
        [{ t: ItemType.GEM, c: 2 + Std.random(2) }]);
    }
    if (tile == (TileType.CACTUS : Int) && kind == SWORD) {
      return accumDamage(sim, tx, ty, data, 5 + Std.random(6), 10, TileType.SAND,
        [{ t: ItemType.CACTUS, c: 1 + Std.random(2) }]);
    }

    // --- Single-hit interactions ---
    if (tile == (TileType.SAND : Int) && kind == SHOVEL) {
      sim.changeTile(tx, ty, TileType.DIRT, 0);
      sim.spawnGroundItem(ItemType.SAND, 1, tx, ty);
      return true;
    }
    if (tile == (TileType.GRASS : Int) && kind == SHOVEL) {
      sim.changeTile(tx, ty, TileType.DIRT, 0);
      if (Std.random(5) == 0) sim.spawnGroundItem(ItemType.SEEDS, 1, tx, ty);
      return true;
    }
    if (tile == (TileType.GRASS : Int) && kind == HOE) {
      sim.changeTile(tx, ty, TileType.FARMLAND, 0);
      if (Std.random(5) == 0) sim.spawnGroundItem(ItemType.SEEDS, 1, tx, ty);
      return true;
    }
    if (tile == (TileType.DIRT : Int) && kind == SHOVEL) {
      sim.changeTile(tx, ty, TileType.HOLE, 0);
      sim.spawnGroundItem(ItemType.DIRT, 1, tx, ty);
      return true;
    }
    if (tile == (TileType.DIRT : Int) && kind == HOE) {
      sim.changeTile(tx, ty, TileType.FARMLAND, 0);
      return true;
    }
    if (tile == (TileType.FARMLAND : Int) && kind == SHOVEL) {
      sim.changeTile(tx, ty, TileType.DIRT, 0);
      return true;
    }
    if (tile == (TileType.FLOWER : Int) && kind == SHOVEL) {
      sim.changeTile(tx, ty, TileType.GRASS, 0);
      sim.spawnGroundItem(ItemType.FLOWER, 2, tx, ty);
      return true;
    }
    if (tile == (TileType.WHEAT : Int) && kind == SHOVEL) {
      sim.changeTile(tx, ty, TileType.DIRT, 0);
      if (Std.random(2) == 0) sim.spawnGroundItem(ItemType.SEEDS, 1, tx, ty);
      var wheat = (data >= 50) ? 2 + Std.random(3) : (data >= 40 ? 1 + Std.random(2) : 0);
      if (wheat > 0) sim.spawnGroundItem(ItemType.WHEAT, wheat, tx, ty);
      return true;
    }
    return false;
  }

  /** Accumulate damage; on reaching the threshold, mutate the tile and drop. */
  static function accumDamage(sim:ZoneSimulator, tx:Int, ty:Int, data:Int, dmg:Int,
      threshold:Int, becomes:TileType, drops:Array<{t:ItemType, c:Int}>):Bool {
    var nd = data + dmg;
    if (nd >= threshold) {
      sim.changeTile(tx, ty, becomes, 0);
      for (d in drops) if (d.c > 0) sim.spawnGroundItem(d.t, d.c, tx, ty);
    } else {
      sim.map.setTileData(tx, ty, nd);
    }
    return true;
  }

  /** Plant a plantable resource onto the matching tile, consuming one. */
  static function tryPlant(sim:ZoneSimulator, ch:Character, item:ItemType,
      tx:Int, ty:Int, tile:Int):Bool {
    var becomes:TileType = TileType.GRASS;
    var ok = false;
    if (item == ItemType.SEEDS && tile == (TileType.FARMLAND : Int)) {
      becomes = TileType.WHEAT; ok = true;
    } else if (item == ItemType.ACORN && tile == (TileType.GRASS : Int)) {
      becomes = TileType.TREE_SAPLING; ok = true;
    } else if (item == ItemType.CACTUS && tile == (TileType.SAND : Int)) {
      becomes = TileType.CACTUS_SAPLING; ok = true;
    } else if (item == ItemType.FLOWER && tile == (TileType.GRASS : Int)) {
      becomes = TileType.FLOWER; ok = true;
    } else if (item == ItemType.DIRT && (tile == (TileType.HOLE : Int)
        || tile == (TileType.WATER : Int) || tile == (TileType.LAVA : Int))) {
      becomes = TileType.DIRT; ok = true;
    } else if (item == ItemType.SAND && (tile == (TileType.GRASS : Int)
        || tile == (TileType.DIRT : Int))) {
      becomes = TileType.SAND; ok = true;
    }
    if (!ok) return false;
    if (!ch.inventory.removeCount(item, 1)) return false;
    sim.changeTile(tx, ty, becomes, 0);
    return true;
  }
}
