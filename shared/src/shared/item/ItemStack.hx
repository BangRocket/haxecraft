package shared.item;

/** A quantity of one item type. Resources stack; tools and furniture sit at
    count 1 per slot. */
class ItemStack {
  public var itemType:ItemType;
  public var count:Int;

  public function new(itemType:ItemType, count:Int = 1) {
    this.itemType = itemType;
    this.count = count;
  }

  public function clone():ItemStack {
    return new ItemStack(itemType, count);
  }
}
