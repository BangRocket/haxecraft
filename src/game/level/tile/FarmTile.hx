package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import game.entity.Player;
import engine.gfx.Color;
import engine.gfx.Screen;
import engine.item.Item;
import game.item.ToolItem;
import engine.item.ToolType;
import engine.level.Level;

class FarmTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var col = Color.get(level.dirtColor - 121, level.dirtColor - 11, level.dirtColor, level.dirtColor + 111);
		screen.render(x * 16 + 0, y * 16 + 0, 2 + 32, 1);
		screen.render(x * 16 + 8, y * 16 + 0, 2 + 32, 0);
		screen.render(x * 16 + 0, y * 16 + 8, 2 + 32, 0);
		screen.render(x * 16 + 8, y * 16 + 8, 2 + 32, 1);
	}

	override public function interact(level:Level, xt:Int, yt:Int, player:Player, item:Item, attackDir:Int):Bool {
		if (Std.isOfType(item, ToolItem)) {
			var tool:ToolItem = cast(item, ToolItem);
			if (tool.type == ToolType.shovel) {
				if (player.payStamina(4 - tool.level)) {
					level.setTile(xt, yt, Tile.dirt, 0);
					return true;
				}
			}
		}
		return false;
	}

	override public function tick(level:Level, xt:Int, yt:Int) {
		var age = level.getData(xt, yt);
		if (age < 5) level.setData(xt, yt, age + 1);
	}

	override public function steppedOn(level:Level, xt:Int, yt:Int, entity:Entity) {
		if (random.nextInt(60) != 0) return;
		if (level.getData(xt, yt) < 5) return;
		level.setTile(xt, yt, Tile.dirt, 0);
	}
}
