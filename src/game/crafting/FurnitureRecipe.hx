package game.crafting;

import game.entity.Furniture;
import game.entity.Player;
import game.item.FurnitureItem;

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
