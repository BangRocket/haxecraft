package shared.item;

/** Broad classification of an ItemType. */
enum abstract ItemCategory(Int) to Int from Int {
  var RESOURCE = 0;
  var TOOL = 1;
  var FURNITURE = 2;
}
