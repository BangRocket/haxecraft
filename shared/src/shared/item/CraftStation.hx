package shared.item;

/** The furniture a recipe is crafted at. */
enum abstract CraftStation(Int) to Int from Int {
  var WORKBENCH = 0;
  var ANVIL = 1;
  var FURNACE = 2;
  var OVEN = 3;
}
