package com.mojang.ld22.screen;

import com.mojang.ld22.entity.Inventory;
import com.mojang.ld22.entity.Player;
import com.mojang.ld22.gfx.Font;
import com.mojang.ld22.gfx.Screen;

class ContainerMenu extends Menu {
	var player:Player;
	var container:Inventory;
	var selected = 0;
	var title:String;
	var oSelected = 0;
	var window = 0;

	public function new(player:Player, title:String, container:Inventory) {
		super();
		this.player = player;
		this.title = title;
		this.container = container;
	}

	override public function tick() {
		if (input.menu.clicked) game.setMenu(null);

		if (input.left.clicked) {
			window = 0;
			var tmp = selected;
			selected = oSelected;
			oSelected = tmp;
		}
		if (input.right.clicked) {
			window = 1;
			var tmp = selected;
			selected = oSelected;
			oSelected = tmp;
		}

		var i = window == 1 ? player.inventory : container;
		var i2 = window == 0 ? player.inventory : container;

		var len = i.items.length;
		if (selected < 0) selected = 0;
		if (selected >= len) selected = len - 1;

		if (input.up.clicked) selected--;
		if (input.down.clicked) selected++;

		if (len == 0) selected = 0;
		if (selected < 0) selected += len;
		if (selected >= len) selected -= len;

		if (input.attack.clicked && len > 0) {
			i2.addSlot(oSelected, i.items.splice(selected, 1)[0]);
			if (selected >= i.items.length) selected = i.items.length - 1;
		}
	}

	override public function render(screen:Screen) {
		if (window == 1) screen.setOffset(6 * 8, 0);
		Font.renderFrame(screen, title, 1, 1, 12, 11);
		renderItemList(screen, 1, 1, 12, 11, cast container.items, window == 0 ? selected : -oSelected - 1);

		Font.renderFrame(screen, "inventory", 13, 1, 13 + 11, 11);
		renderItemList(screen, 13, 1, 13 + 11, 11, cast player.inventory.items, window == 1 ? selected : -oSelected - 1);
		screen.setOffset(0, 0);
	}
}
