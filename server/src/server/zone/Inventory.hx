package server.zone;

import shared.item.ItemType;

/** A mobile's carried items, slot-ordered. Items are first-class records
    with their own serial. Two add paths:

      - `addFresh(item)` — for a newly-allocated item with no DB row yet
        (crafting output, bootstrap kit). Stack merges bump an existing
        slot's count and discard the new item silently; non-merge inserts
        via `onAdd`.

      - `addExisting(item)` — for an item that already has a DB row
        (pickup from world, future inter-container move). Stack merges
        bump the existing slot and destroy the incoming row via
        `onDestroy`; non-merge re-parents via `onReparent`.

    The simulator installs the four `on*` hooks to plumb persistence + wire
    events. */
class Inventory {
  public var slots(default, null):Array<Item> = [];
  public var activeSlot:Int = 0;
  public var owner(default, null):Mobile;

  public var onAdd:Item -> Void = function(_) {};
  public var onSlotCountChanged:Item -> Void = function(_) {};
  public var onDestroy:Item -> Void = function(_) {};
  public var onReparent:Item -> Void = function(_) {};

  public function new(owner:Mobile) {
    this.owner = owner;
  }

  /** Add a freshly-allocated item with no DB row yet. Stack-merge of a
      stackable type bumps the existing slot's count and discards the
      incoming item silently (no DB delete needed — it was never persisted). */
  public function addFresh(item:Item):Void {
    if (item.itemType.stackable()) {
      for (s in slots) {
        if (s.itemType == item.itemType) {
          s.count += item.count;
          onSlotCountChanged(s);
          return;
        }
      }
    }
    item.parent = owner;
    item.slot = slots.length;
    slots.push(item);
    onAdd(item);
  }

  /** Add an item that already has a DB row (e.g. a ground item being picked
      up). Stack-merge of a stackable type bumps the existing slot and
      destroys the incoming row; non-merge re-parents it. */
  public function addExisting(item:Item):Void {
    if (item.itemType.stackable()) {
      for (s in slots) {
        if (s.itemType == item.itemType) {
          s.count += item.count;
          onSlotCountChanged(s);
          onDestroy(item);
          return;
        }
      }
    }
    item.parent = owner;
    item.slot = slots.length;
    slots.push(item);
    onReparent(item);
  }

  public function countOf(itemType:ItemType):Int {
    var n = 0;
    for (s in slots) if (s.itemType == itemType) n += s.count;
    return n;
  }

  public function has(itemType:ItemType, count:Int):Bool {
    return countOf(itemType) >= count;
  }

  /** Remove `count` of `itemType`. Slots that empty are destroyed via
      `onDestroy`; subsequent slots reindex via `onReparent`. */
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
        if (s.count <= 0) {
          slots.splice(i, 1);
          onDestroy(s);
          reindexFrom(i);
          continue;
        } else {
          onSlotCountChanged(s);
        }
      }
      i++;
    }
    return true;
  }

  public function activeItem():Null<Item> {
    if (activeSlot < 0 || activeSlot >= slots.length) return null;
    return slots[activeSlot];
  }

  public function isEmpty():Bool return slots.length == 0;

  /** Flatten to plain rows for MsgInventory and tests. */
  public function toRows():Array<{itemTypeId:Int, count:Int}> {
    return [for (s in slots) { itemTypeId: (s.itemType : Int), count: s.count }];
  }

  function reindexFrom(start:Int):Void {
    for (i in start...slots.length) {
      var s = slots[i];
      if (s.slot != i) {
        s.slot = i;
        onReparent(s);
      }
    }
  }
}
