package server.zone;

import shared.Constants;
import shared.item.ItemType;

/**
 * Deterministically populates a zone with world objects and ground items.
 * Server-side, runs once at zone boot. No map/TMX change — placement is code.
 */
class WorldPopulator {
  /** Furniture camp: one of each type, at fixed offsets from the spawn tile. */
  static var CAMP:Array<{ t:ItemType, dx:Int, dy:Int }> = [
    { t: ItemType.WORKBENCH, dx: -3, dy: -3 },
    { t: ItemType.FURNACE,   dx: -1, dy: -3 },
    { t: ItemType.OVEN,      dx:  1, dy: -3 },
    { t: ItemType.ANVIL,     dx:  3, dy: -3 },
    { t: ItemType.CHEST,     dx: -3, dy: -1 },
    { t: ItemType.LANTERN,   dx:  3, dy: -1 },
  ];

  /** Resource types eligible for the ground-item scatter. */
  static var SCATTER:Array<ItemType> = [
    ItemType.WOOD, ItemType.STONE, ItemType.COAL, ItemType.IRON_ORE,
    ItemType.GOLD_ORE, ItemType.APPLE, ItemType.GEM, ItemType.CLOTH,
  ];

  static inline var SCATTER_COUNT = 40;
  static inline var SCATTER_RADIUS = 24;
  static inline var SEED = 0x5C2117E;

  public static function populate(sim:ZoneSimulator):Void {
    // Anchor on a guaranteed-walkable tile near the nominal spawn — on the
    // procgen map DEFAULT_SPAWN itself may land in water/rock.
    var anchor = sim.map.findWalkableNear(Constants.DEFAULT_SPAWN_X, Constants.DEFAULT_SPAWN_Y);
    var spawnX = anchor.x;
    var spawnY = anchor.y;

    // World objects: a fixed furniture camp just off the spawn tile.
    var oid = 1;
    for (slot in CAMP) {
      var tx = spawnX + slot.dx;
      var ty = spawnY + slot.dy;
      // Procgen variance: skip a slot whose tile is not walkable terrain.
      if (!sim.map.isWalkable(tx, ty)) continue;
      sim.addWorldObject(new WorldObject(oid++, slot.t, tx, ty));
    }

    // Ground items: deterministic scatter across walkable tiles near spawn.
    var rng = new SeededRng(SEED);
    var iid = 1;
    var placed = 0;
    var attempts = 0;
    while (placed < SCATTER_COUNT && attempts < SCATTER_COUNT * 100) {
      attempts++;
      var tx = spawnX + rng.range(-SCATTER_RADIUS, SCATTER_RADIUS);
      var ty = spawnY + rng.range(-SCATTER_RADIUS, SCATTER_RADIUS);
      if (!sim.map.isWalkable(tx, ty)) continue;
      if (sim.objectAt(tx, ty)) continue;
      var t = SCATTER[rng.nextInt(SCATTER.length)];
      var count = t.stackable() ? 1 + rng.nextInt(5) : 1;
      sim.addGroundItem(new GroundItem(iid++, t, count, tx, ty));
      placed++;
    }
  }
}
