package game.crafting;

import game.entity.Player;
import game.item.ResourceItem;
import engine.item.resource.Resource;

class ResourceRecipe extends Recipe {
	private var resource:Resource;

	public function new(resource:Resource) {
		super(new ResourceItem(resource, 1));
		this.resource = resource;
	}

	override public function craft(player:Player):Void {
		player.inventory.addSlot(0, new ResourceItem(resource, 1));
	}
}
