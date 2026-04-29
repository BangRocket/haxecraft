package com.mojang.ld22.level.tile;

import com.mojang.ld22.entity.Entity;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.level.Level;
import com.mojang.ld22.utils.Random;

class LavaTile extends Tile {
	var wRandom:Random = new Random();

	public function new(id:Int) {
		super(id);
		connectsToSand = true;
		connectsToLava = true;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var intSeed = Std.int((Tile.tickCount + Std.int(x / 2 - y) * 4311) / 10);
		var seed = haxe.Int64.ofInt(intSeed) * haxe.Int64.parseString("54687121");
		seed = seed + haxe.Int64.ofInt(x * 3271612);
		seed = seed + haxe.Int64.ofInt(y) * haxe.Int64.parseString("3412987161");
		wRandom.setSeed(seed);
		var col = Color.get(500, 500, 520, 550);
		var transitionColor1 = Color.get(3, 500, level.dirtColor - 111, level.dirtColor);
		var transitionColor2 = Color.get(3, 500, level.sandColor - 110, level.sandColor);

		var u = !level.getTile(x, y - 1).connectsToLava;
		var d = !level.getTile(x, y + 1).connectsToLava;
		var l = !level.getTile(x - 1, y).connectsToLava;
		var r = !level.getTile(x + 1, y).connectsToLava;

		var su = u && level.getTile(x, y - 1).connectsToSand;
		var sd = d && level.getTile(x, y + 1).connectsToSand;
		var sl = l && level.getTile(x - 1, y).connectsToSand;
		var sr = r && level.getTile(x + 1, y).connectsToSand;

		if (!u && !l) {
			screen.render(x * 16 + 0, y * 16 + 0, wRandom.nextInt(4), col, wRandom.nextInt(4));
		} else {
			screen.render(x * 16 + 0, y * 16 + 0, (l ? 14 : 15) + (u ? 0 : 1) * 32, (su || sl) ? transitionColor2 : transitionColor1, 0);
		}

		if (!u && !r) {
			screen.render(x * 16 + 8, y * 16 + 0, wRandom.nextInt(4), col, wRandom.nextInt(4));
		} else {
			screen.render(x * 16 + 8, y * 16 + 0, (r ? 16 : 15) + (u ? 0 : 1) * 32, (su || sr) ? transitionColor2 : transitionColor1, 0);
		}

		if (!d && !l) {
			screen.render(x * 16 + 0, y * 16 + 8, wRandom.nextInt(4), col, wRandom.nextInt(4));
		} else {
			screen.render(x * 16 + 0, y * 16 + 8, (l ? 14 : 15) + (d ? 2 : 1) * 32, (sd || sl) ? transitionColor2 : transitionColor1, 0);
		}
		if (!d && !r) {
			screen.render(x * 16 + 8, y * 16 + 8, wRandom.nextInt(4), col, wRandom.nextInt(4));
		} else {
			screen.render(x * 16 + 8, y * 16 + 8, (r ? 16 : 15) + (d ? 2 : 1) * 32, (sd || sr) ? transitionColor2 : transitionColor1, 0);
		}
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return e.canSwim();
	}

	override public function tick(level:Level, xt:Int, yt:Int) {
		var xn = xt;
		var yn = yt;

		if (random.nextBoolean())
			xn += random.nextInt(2) * 2 - 1;
		else
			yn += random.nextInt(2) * 2 - 1;

		if (level.getTile(xn, yn) == Tile.hole) {
			level.setTile(xn, yn, this, 0);
		}
	}

	override public function getLightRadius(level:Level, x:Int, y:Int):Int {
		return 6;
	}
}
