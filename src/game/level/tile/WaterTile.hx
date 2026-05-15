package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.gfx.Color;
import engine.gfx.Screen;
import game.SpriteNames;
import engine.level.Level;
import engine.utils.Random;

class WaterTile extends Tile {
	var wRandom:Random = new Random();

	public function new(id:Int) {
		super(id);
		connectsToSand = true;
		connectsToWater = true;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var intSeed = Std.int((Tile.tickCount + Std.int(x / 2 - y) * 4311) / 10);
		var seed = haxe.Int64.ofInt(intSeed) * haxe.Int64.parseString("54687121");
		seed = seed + haxe.Int64.ofInt(x * 3271612);
		seed = seed + haxe.Int64.ofInt(y) * haxe.Int64.parseString("3412987161");
		wRandom.setSeed(seed);
		var col = Color.get(5, 5, 115, 115);
		var transitionColor1 = Color.get(3, 5, level.dirtColor - 111, level.dirtColor);
		var transitionColor2 = Color.get(3, 5, level.sandColor - 110, level.sandColor);

		var u = !level.getTile(x, y - 1).connectsToWater;
		var d = !level.getTile(x, y + 1).connectsToWater;
		var l = !level.getTile(x - 1, y).connectsToWater;
		var r = !level.getTile(x + 1, y).connectsToWater;

		var su = u && level.getTile(x, y - 1).connectsToSand;
		var sd = d && level.getTile(x, y + 1).connectsToSand;
		var sl = l && level.getTile(x - 1, y).connectsToSand;
		var sr = r && level.getTile(x + 1, y).connectsToSand;

		if (!u && !l) {
			screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_BASE[wRandom.nextInt(4)], col, wRandom.nextInt(4));
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.edgeWaterTL(l, u), (su || sl) ? transitionColor2 : transitionColor1, 0);
		}

		if (!u && !r) {
			screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_BASE[wRandom.nextInt(4)], col, wRandom.nextInt(4));
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.edgeWaterTR(r, u), (su || sr) ? transitionColor2 : transitionColor1, 0);
		}

		if (!d && !l) {
			screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_BASE[wRandom.nextInt(4)], col, wRandom.nextInt(4));
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.edgeWaterBL(l, d), (sd || sl) ? transitionColor2 : transitionColor1, 0);
		}
		if (!d && !r) {
			screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_BASE[wRandom.nextInt(4)], col, wRandom.nextInt(4));
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.edgeWaterBR(r, d), (sd || sr) ? transitionColor2 : transitionColor1, 0);
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
}
