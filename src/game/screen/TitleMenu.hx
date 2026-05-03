package game.screen;

import engine.screen.Menu;

import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;
import engine.sound.Sound;

class TitleMenu extends Menu {
	var selected = 0;

	static var options = ["Start game", "How to play", "About"];

	public function new() {
		super();
	}

	override public function tick() {
		if (input.up.clicked) selected--;
		if (input.down.clicked) selected++;

		var len = options.length;
		if (selected < 0) selected += len;
		if (selected >= len) selected -= len;

		if (input.attack.clicked || input.menu.clicked) {
			if (selected == 0) {
				Sound.test.play();
				game.resetGame();
				game.setMenu(null);
			}
			if (selected == 1) game.setMenu(new InstructionsMenu(this));
			if (selected == 2) game.setMenu(new AboutMenu(this));
		}
	}

	override public function render(screen:Screen) {
		screen.clear(0);

		var h = 2;
		var w = 13;
		var titleColor = Color.get(0, 10, 131, 551);
		var xo = Std.int((screen.w - w * 8) / 2);
		var yo = 24;
		for (y in 0...h) {
			for (x in 0...w) {
				screen.render(xo + x * 8, yo + y * 8, x + (y + 6) * 32, titleColor, 0);
			}
		}

		for (i in 0...3) {
			var msg = options[i];
			var col = Color.get(0, 222, 222, 222);
			if (i == selected) {
				msg = "> " + msg + " <";
				col = Color.get(0, 555, 555, 555);
			}
			Font.draw(msg, screen, Std.int((screen.w - msg.length * 8) / 2), (8 + i) * 8, col);
		}

		Font.draw("(Arrow keys,X and C)", screen, 0, screen.h - 8, Color.get(0, 111, 111, 111));
	}
}
