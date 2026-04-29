package com.mojang.ld22.crafting;

import com.mojang.ld22.entity.Furniture;
import com.mojang.ld22.entity.Player;
import com.mojang.ld22.item.FurnitureItem;

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
