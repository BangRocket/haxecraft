package game.screen;


import engine.gfx.Screen;
import game.SpriteNames;

class LevelTransitionMenu extends GameMenu {
	var dir:Int;
	var time = 0;

	public function new(dir:Int) {
		super();
		this.dir = dir;
	}

	override public function tick() {
		time += 2;
		if (time == 30) game.changeLevel(dir);
		if (time == 60) game.setMenu(null);
	}

	override public function render(screen:Screen) {
		for (x in 0...20) {
			for (y in 0...15) {
				var dd = (y + x % 2 * 2 + Std.int(x / 3)) - time;
				if (dd < 0 && dd > -30) {
					if (dir > 0)
						screen.renderSprite(x * 8, y * 8, SpriteNames.TERRAIN_BASE[0], 0, 0);
					else
						screen.renderSprite(x * 8, screen.h - y * 8 - 8, SpriteNames.TERRAIN_BASE[0], 0, 0);
				}
			}
		}
	}
}
