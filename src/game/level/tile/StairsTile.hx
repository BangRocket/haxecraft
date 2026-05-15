package game.level.tile;

import engine.level.tile.Tile;

import engine.gfx.Color;
import engine.gfx.Screen;
import engine.level.Level;
import game.SpriteNames;

class StairsTile extends Tile {
	var leadsUp:Bool;

	public function new(id:Int, leadsUp:Bool) {
		super(id);
		this.leadsUp = leadsUp;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var color = Color.get(level.dirtColor, 0, 333, 444);
		var sprites = leadsUp ? SpriteNames.TERRAIN_STAIRS_UP : SpriteNames.TERRAIN_STAIRS_DOWN;
		screen.renderSprite(x * 16 + 0, y * 16 + 0, sprites[0], color, 0);
		screen.renderSprite(x * 16 + 8, y * 16 + 0, sprites[1], color, 0);
		screen.renderSprite(x * 16 + 0, y * 16 + 8, sprites[2], color, 0);
		screen.renderSprite(x * 16 + 8, y * 16 + 8, sprites[3], color, 0);
	}
}
