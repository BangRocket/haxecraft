package crafting;

import entity.Furniture;
import entity.Player;
import item.FurnitureItem;

class FurnitureRecipe extends Recipe {
	private var factory:Void->Furniture;

	public function new(factory:Void->Furniture) {
		super(new FurnitureItem(factory()));
		this.factory = factory;
	}

	override public function craft(player:Player):Void {
		player.inventory.addSlot(0, new FurnitureItem(factory()));
	}
}
