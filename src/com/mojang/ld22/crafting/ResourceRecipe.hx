package com.mojang.ld22.crafting;

import com.mojang.ld22.entity.Player;
import com.mojang.ld22.item.ResourceItem;
import com.mojang.ld22.item.resource.Resource;

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
