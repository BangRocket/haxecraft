package server.zone;

import shared.item.ItemType;
import shared.item.ItemCategory;
import shared.item.CraftStation;
import shared.item.RecipeBook;

/** Server-side crafting: validate proximity to a station, consume inputs,
    produce the output. Also furniture placement. */
class Crafting {
  /** Craft a recipe for `m`. Requires standing next to a matching station
      and holding every input. Returns true on success. */
  public static function craft(sim:ZoneSimulator, m:Mobile, recipeId:Int):Bool {
    var recipe = RecipeBook.byId(recipeId);
    if (recipe == null) return false;
    if (!nearObject(sim, m, stationItemType(recipe.station))) return false;

    for (inp in recipe.inputs) {
      if (!m.inventory.has(inp.itemType, inp.count)) return false;
    }
    for (inp in recipe.inputs) {
      m.inventory.removeCount(inp.itemType, inp.count);
    }
    var output = new Item(sim.serials.nextItem(), recipe.output, recipe.outputCount);
    m.inventory.addFresh(output);
    return true;
  }

  /** Place the active furniture item at (tx, ty). Returns the new world-
      placed item, or null if the placement is invalid. */
  public static function place(sim:ZoneSimulator, m:Mobile, tx:Int, ty:Int):Null<Item> {
    var active = m.inventory.activeItem();
    if (active == null) return null;
    var item = active.itemType;
    if (item.category() != ItemCategory.FURNITURE) return null;
    if (Math.abs(tx - m.tileX) > 1 || Math.abs(ty - m.tileY) > 1) return null;
    if (!sim.map.isWalkable(tx, ty)) return null;
    if (sim.objectAt(tx, ty) || sim.entityAt(tx, ty) != null) return null;

    if (!m.inventory.removeCount(item, 1)) return null;
    return sim.spawnItem(item, 1, tx, ty);
  }

  static function stationItemType(s:CraftStation):ItemType {
    if (s == CraftStation.WORKBENCH) return ItemType.WORKBENCH;
    if (s == CraftStation.ANVIL) return ItemType.ANVIL;
    if (s == CraftStation.FURNACE) return ItemType.FURNACE;
    return ItemType.OVEN;
  }

  static function nearObject(sim:ZoneSimulator, m:Mobile, objType:ItemType):Bool {
    for (o in sim.worldObjects()) {
      if (o.itemType == objType
          && Math.abs(o.tileX - m.tileX) <= 1
          && Math.abs(o.tileY - m.tileY) <= 1) {
        return true;
      }
    }
    return false;
  }
}
