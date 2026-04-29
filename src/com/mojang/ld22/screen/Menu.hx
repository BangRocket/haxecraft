package com.mojang.ld22.screen;

import com.mojang.ld22.Game;
import com.mojang.ld22.InputHandler;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Font;
import com.mojang.ld22.gfx.Screen;

class Menu {
	var game:Game;
	var input:InputHandler;

	public function new() {}

	public function init(game:Game, input:InputHandler) {
		this.input = input;
		this.game = game;
	}

	public function tick() {}

	public function render(screen:Screen) {}

	public function renderItemList(screen:Screen, xo:Int, yo:Int, x1:Int, y1:Int, listItems:Array<ListItem>, selected:Int) {
		var renderCursor = true;
		if (selected < 0) {
			selected = -selected - 1;
			renderCursor = false;
		}
		var w = x1 - xo;
		var h = y1 - yo - 1;
		var i0 = 0;
		var i1 = listItems.length;
		if (i1 > h) i1 = h;
		var io = selected - Std.int(h / 2);
		if (io > listItems.length - h) io = listItems.length - h;
		if (io < 0) io = 0;

		for (i in i0...i1) {
			listItems[i + io].renderInventory(screen, (1 + xo) * 8, (i + 1 + yo) * 8);
		}

		if (renderCursor) {
			var yy = selected + 1 - io + yo;
			Font.draw(">", screen, (xo + 0) * 8, yy * 8, Color.get(5, 555, 555, 555));
			Font.draw("<", screen, (xo + w) * 8, yy * 8, Color.get(5, 555, 555, 555));
		}
	}
}
