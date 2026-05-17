package engine.screen;

import engine.Engine;
import game.InputHandler;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;

class Menu {
	var engine:Engine;
	var input:InputHandler;

	public function new() {}

	public function init(engine:Engine, input:InputHandler) {
		this.input = input;
		this.engine = engine;
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
