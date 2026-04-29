package com.mojang.ld22.entity;

import com.mojang.ld22.crafting.Crafting;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.screen.CraftingMenu;

class Anvil extends Furniture {
	public function new() {
		super("Anvil");
		col = Color.get(-1, 0, 111, 222);
		sprite = 0;
		xr = 3;
		yr = 2;
	}

	override public function use(player:Player, attackDir:Int):Bool {
		player.game.setMenu(new CraftingMenu(Crafting.anvilRecipes, player));
		return true;
	}
}
