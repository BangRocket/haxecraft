package com.mojang.ld22.entity;

import com.mojang.ld22.crafting.Crafting;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.screen.CraftingMenu;

class Oven extends Furniture {
	public function new() {
		super("Oven");
		col = Color.get(-1, 0, 332, 442);
		sprite = 2;
		xr = 3;
		yr = 2;
	}

	override public function use(player:Player, attackDir:Int):Bool {
		player.game.setMenu(new CraftingMenu(Crafting.ovenRecipes, player));
		return true;
	}
}
