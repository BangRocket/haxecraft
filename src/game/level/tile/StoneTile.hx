package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.gfx.Color;
import engine.gfx.Screen;
import engine.level.Level;
import game.SpriteNames;

class StoneTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var rc1 = 111;
		var rc2 = 333;
		var rc3 = 555;
		screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_BEDROCK, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
		screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_BEDROCK, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
		screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_BEDROCK, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
		screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_BEDROCK, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return false;
	}
}
