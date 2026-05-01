package level.tile;

import entity.Entity;
import gfx.Color;
import gfx.Screen;
import level.Level;

class HoleTile extends Tile {
	public function new(id:Int) {
		super(id);
		connectsToSand = true;
		connectsToWater = true;
		connectsToLava = true;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var col = Color.get(111, 111, 110, 110);
		var transitionColor1 = Color.get(3, 111, level.dirtColor - 111, level.dirtColor);
		var transitionColor2 = Color.get(3, 111, level.sandColor - 110, level.sandColor);

		var u = !level.getTile(x, y - 1).connectsToLiquid();
		var d = !level.getTile(x, y + 1).connectsToLiquid();
		var l = !level.getTile(x - 1, y).connectsToLiquid();
		var r = !level.getTile(x + 1, y).connectsToLiquid();

		var su = u && level.getTile(x, y - 1).connectsToSand;
		var sd = d && level.getTile(x, y + 1).connectsToSand;
		var sl = l && level.getTile(x - 1, y).connectsToSand;
		var sr = r && level.getTile(x + 1, y).connectsToSand;

		if (!u && !l) {
			screen.render(x * 16 + 0, y * 16 + 0, 0, 0);
		} else {
			screen.render(x * 16 + 0, y * 16 + 0, (l ? 14 : 15) + (u ? 0 : 1) * 32, 0);
		}

		if (!u && !r) {
			screen.render(x * 16 + 8, y * 16 + 0, 1, 0);
		} else {
			screen.render(x * 16 + 8, y * 16 + 0, (r ? 16 : 15) + (u ? 0 : 1) * 32, 0);
		}

		if (!d && !l) {
			screen.render(x * 16 + 0, y * 16 + 8, 2, 0);
		} else {
			screen.render(x * 16 + 0, y * 16 + 8, (l ? 14 : 15) + (d ? 2 : 1) * 32, 0);
		}
		if (!d && !r) {
			screen.render(x * 16 + 8, y * 16 + 8, 3, 0);
		} else {
			screen.render(x * 16 + 8, y * 16 + 8, (r ? 16 : 15) + (d ? 2 : 1) * 32, 0);
		}
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return e.canSwim();
	}
}
