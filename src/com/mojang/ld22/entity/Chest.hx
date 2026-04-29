package com.mojang.ld22.entity;

import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.screen.ContainerMenu;

class Chest extends Furniture {
	public var inventory:Inventory = new Inventory();

	public function new() {
		super("Chest");
		col = Color.get(-1, 110, 331, 552);
		sprite = 1;
	}

	override public function use(player:Player, attackDir:Int):Bool {
		player.game.setMenu(new ContainerMenu(player, "Chest", inventory));
		return true;
	}
}
