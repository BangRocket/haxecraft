package server.zone;

import shared.item.ItemType;
import shared.item.ItemStack;

/** A character's carried items — an ordered list of slots. Resources merge
    into one slot per type; tools and furniture take a slot each. */
class Inventory {
  public var slots(default, null):Array<ItemStack> = [];
  public var activeSlot:Int = 0;

  public function new() {}

  /** Add `count` of an item. Stackable types merge into an existing slot. */
  public function add(itemType:ItemType, count:Int = 1):Void {
    if (count <= 0) return;
    if (itemType.stackable()) {
      for (s in slots) {
        if (s.itemType == itemType) { s.count += count; return; }
      }
    }
    slots.push(new ItemStack(itemType, count));
  }

  /** Total held count of an item type across all slots. */
  public function countOf(itemType:ItemType):Int {
    var n = 0;
    for (s in slots) if (s.itemType == itemType) n += s.count;
    return n;
  }

  public function has(itemType:ItemType, count:Int):Bool {
    return countOf(itemType) >= count;
  }

  /** Remove `count` of an item type. No-op + false if not enough is held. */
  public function removeCount(itemType:ItemType, count:Int):Bool {
    if (!has(itemType, count)) return false;
    var remaining = count;
    var i = 0;
    while (i < slots.length && remaining > 0) {
      var s = slots[i];
      if (s.itemType == itemType) {
        var take = (s.count < remaining) ? s.count : remaining;
        s.count -= take;
        remaining -= take;
        if (s.count <= 0) { slots.splice(i, 1); continue; }
      }
      i++;
    }
    return true;
  }

  /** The slot the player currently has selected, or null. */
  public function activeItem():Null<ItemStack> {
    if (activeSlot < 0 || activeSlot >= slots.length) return null;
    return slots[activeSlot];
  }

  public function isEmpty():Bool {
    return slots.length == 0;
  }
}
