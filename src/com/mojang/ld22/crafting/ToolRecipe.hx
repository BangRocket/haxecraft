package com.mojang.ld22.crafting;

import com.mojang.ld22.entity.Player;
import com.mojang.ld22.item.ToolItem;
import com.mojang.ld22.item.ToolType;

class ToolRecipe extends Recipe {
	private var type:ToolType;
	private var level:Int;

	public function new(type:ToolType, level:Int) {
		super(new ToolItem(type, level));
		this.type = type;
		this.level = level;
	}

	override public function craft(player:Player):Void {
		player.inventory.addSlot(0, new ToolItem(type, level));
	}
}
