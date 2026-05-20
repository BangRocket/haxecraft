package shared.item;

/** A (item type, count) pair used by Recipe to describe inputs.
    Not an inventory entry — inventory entries are server.zone.Item, which
    have serials and parents; this is just a quantity in a recipe. */
typedef RecipeInput = { itemType:ItemType, count:Int };
