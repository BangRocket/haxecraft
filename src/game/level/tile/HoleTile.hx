package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.gfx.Color;
import engine.gfx.Screen;
import game.SpriteNames;
import engine.level.Level;

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
			screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_BASE[0], col, 0);
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.edgeWaterTL(l, u), (su || sl) ? transitionColor2 : transitionColor1, 0);
		}

		if (!u && !r) {
			screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_BASE[1], col, 0);
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.edgeWaterTR(r, u), (su || sr) ? transitionColor2 : transitionColor1, 0);
		}

		if (!d && !l) {
			screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_BASE[2], col, 0);
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.edgeWaterBL(l, d), (sd || sl) ? transitionColor2 : transitionColor1, 0);
		}
		if (!d && !r) {
			screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_BASE[3], col, 0);
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.edgeWaterBR(r, d), (sd || sr) ? transitionColor2 : transitionColor1, 0);
		}
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return e.canSwim();
	}
}
