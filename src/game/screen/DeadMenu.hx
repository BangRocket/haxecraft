package game.screen;

import engine.screen.Menu;

import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;

class DeadMenu extends Menu {
	var inputDelay = 60;

	public function new() {
		super();
	}

	override public function tick() {
		if (inputDelay > 0)
			inputDelay--;
		else if (input.attack.clicked || input.menu.clicked) {
			game.setMenu(new TitleMenu());
		}
	}

	override public function render(screen:Screen) {
		Font.renderFrame(screen, "", 1, 3, 18, 9);
		Font.draw("You died! Aww!", screen, 2 * 8, 4 * 8, Color.get(-1, 555, 555, 555));

		var seconds = Std.int(game.gameTime / 60);
		var minutes = Std.int(seconds / 60);
		var hours = Std.int(minutes / 60);
		minutes %= 60;
		seconds %= 60;

		var timeString = "";
		if (hours > 0) {
			timeString = hours + "h" + (minutes < 10 ? "0" : "") + minutes + "m";
		} else {
			timeString = minutes + "m " + (seconds < 10 ? "0" : "") + seconds + "s";
		}
		Font.draw("Time:", screen, 2 * 8, 5 * 8, Color.get(-1, 555, 555, 555));
		Font.draw(timeString, screen, (2 + 5) * 8, 5 * 8, Color.get(-1, 550, 550, 550));
		Font.draw("Score:", screen, 2 * 8, 6 * 8, Color.get(-1, 555, 555, 555));
		Font.draw("" + game.player.score, screen, (2 + 6) * 8, 6 * 8, Color.get(-1, 550, 550, 550));
		Font.draw("Press C to lose", screen, 2 * 8, 8 * 8, Color.get(-1, 333, 333, 333));
	}
}
