package entity;

import crafting.Crafting;
import gfx.Color;
import screen.CraftingMenu;

class Furnace extends Furniture {
	public function new() {
		super("Furnace");
		col = Color.get(-1, 0, 222, 333);
		sprite = 3;
		xr = 3;
		yr = 2;
	}

	override public function use(player:Player, attackDir:Int):Bool {
		player.game.setMenu(new CraftingMenu(Crafting.furnaceRecipes, player));
		return true;
	}
}
