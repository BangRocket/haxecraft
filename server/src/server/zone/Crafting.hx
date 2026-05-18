package server.zone;

import shared.item.ItemType;
import shared.item.ItemCategory;
import shared.item.CraftStation;
import shared.item.RecipeBook;

/** Server-side crafting: validate proximity to a station, consume inputs,
    produce the output. Also furniture placement. */
class Crafting {
  /** Craft a recipe for `ch`. Requires standing next to a matching station
      and holding every input. Returns true on success. */
  public static function craft(sim:ZoneSimulator, ch:Character, recipeId:Int):Bool {
    var recipe = RecipeBook.byId(recipeId);
    if (recipe == null) return false;
    if (!nearObject(sim, ch, stationItemType(recipe.station))) return false;

    for (inp in recipe.inputs) {
      if (!ch.inventory.has(inp.itemType, inp.count)) return false;
    }
    for (inp in recipe.inputs) {
      ch.inventory.removeCount(inp.itemType, inp.count);
    }
    ch.inventory.add(recipe.output, recipe.outputCount);
    return true;
  }

  /** Place the active furniture item at (tx, ty). Returns the new object,
      or null if the placement is invalid. */
  public static function place(sim:ZoneSimulator, ch:Character, tx:Int, ty:Int):Null<WorldObject> {
    var active = ch.inventory.activeItem();
    if (active == null) return null;
    var item = active.itemType;
    if (item.category() != ItemCategory.FURNITURE) return null;
    if (Math.abs(tx - ch.tileX) > 1 || Math.abs(ty - ch.tileY) > 1) return null;
    if (!sim.map.isWalkable(tx, ty)) return null;
    if (sim.objectAt(tx, ty) || sim.entityAt(tx, ty) != null) return null;

    if (!ch.inventory.removeCount(item, 1)) return null;
    var obj = new WorldObject(sim.freshObjectId(), item, tx, ty);
    sim.addWorldObject(obj);
    return obj;
  }

  static function stationItemType(s:CraftStation):ItemType {
    if (s == CraftStation.WORKBENCH) return ItemType.WORKBENCH;
    if (s == CraftStation.ANVIL) return ItemType.ANVIL;
    if (s == CraftStation.FURNACE) return ItemType.FURNACE;
    return ItemType.OVEN;
  }

  static function nearObject(sim:ZoneSimulator, ch:Character, objType:ItemType):Bool {
    for (o in sim.worldObjects) {
      if (o.objectType == objType
          && Math.abs(o.tileX - ch.tileX) <= 1
          && Math.abs(o.tileY - ch.tileY) <= 1) {
        return true;
      }
    }
    return false;
  }
}
