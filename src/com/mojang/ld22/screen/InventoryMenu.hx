package com.mojang.ld22.screen;

import com.mojang.ld22.entity.Player;
import com.mojang.ld22.gfx.Font;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.item.Item;

class InventoryMenu extends Menu {
	var player:Player;
	var selected = 0;

	public function new(player:Player) {
		super();
		this.player = player;

		if (player.activeItem != null) {
			player.inventory.items.insert(0, player.activeItem);
			player.activeItem = null;
		}
	}

	override public function tick() {
		if (input.menu.clicked) game.setMenu(null);

		if (input.up.clicked) selected--;
		if (input.down.clicked) selected++;

		var len = player.inventory.items.length;
		if (len == 0) selected = 0;
		if (selected < 0) selected += len;
		if (selected >= len) selected -= len;

		if (input.attack.clicked && len > 0) {
			var item = player.inventory.items[selected];
			player.inventory.items.splice(selected, 1);
			player.activeItem = item;
			game.setMenu(null);
		}
	}

	override public function render(screen:Screen) {
		Font.renderFrame(screen, "inventory", 1, 1, 12, 11);
		renderItemList(screen, 1, 1, 12, 11, cast player.inventory.items, selected);
	}
}
