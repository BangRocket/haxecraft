package level.tile;

import entity.Entity;
import gfx.Color;
import gfx.Screen;
import level.Level;

class StoneTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var rc1 = 111;
		var rc2 = 333;
		var rc3 = 555;
		screen.render(x * 16 + 0, y * 16 + 0, 32, 0);
		screen.render(x * 16 + 8, y * 16 + 0, 32, 0);
		screen.render(x * 16 + 0, y * 16 + 8, 32, 0);
		screen.render(x * 16 + 8, y * 16 + 8, 32, 0);
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return false;
	}
}
