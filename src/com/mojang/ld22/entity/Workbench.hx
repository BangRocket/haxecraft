package com.mojang.ld22.entity;

import com.mojang.ld22.crafting.Crafting;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.screen.CraftingMenu;

class Workbench extends Furniture {
	public function new() {
		super("Workbench");
		col = Color.get(-1, 100, 321, 431);
		sprite = 4;
		xr = 3;
		yr = 2;
	}

	override public function use(player:Player, attackDir:Int):Bool {
		player.game.setMenu(new CraftingMenu(Crafting.workbenchRecipes, player));
		return true;
	}
}
