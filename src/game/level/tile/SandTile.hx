package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.entity.ItemEntity;
import engine.entity.Mob;
import game.entity.Player;
import engine.gfx.Color;
import engine.gfx.Screen;
import engine.item.Item;
import game.item.ResourceItem;
import game.item.ToolItem;
import engine.item.ToolType;
import engine.item.resource.Resource;
import engine.level.Level;

class SandTile extends Tile {
	public function new(id:Int) {
		super(id);
		connectsToSand = true;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var col = Color.get(level.sandColor + 2, level.sandColor, level.sandColor - 110, level.sandColor - 110);
		var transitionColor = Color.get(level.sandColor - 110, level.sandColor, level.sandColor - 110, level.dirtColor);

		var u = !level.getTile(x, y - 1).connectsToSand;
		var d = !level.getTile(x, y + 1).connectsToSand;
		var l = !level.getTile(x - 1, y).connectsToSand;
		var r = !level.getTile(x + 1, y).connectsToSand;

		var steppedOn = level.getData(x, y) > 0;

		if (!u && !l) {
			if (!steppedOn)
				screen.render(x * 16 + 0, y * 16 + 0, 0, 0);
			else
				screen.render(x * 16 + 0, y * 16 + 0, 3 + 1 * 32, 0);
		} else {
			screen.render(x * 16 + 0, y * 16 + 0, (l ? 11 : 12) + (u ? 0 : 1) * 32, 0);
		}

		if (!u && !r) {
			screen.render(x * 16 + 8, y * 16 + 0, 1, 0);
		} else {
			screen.render(x * 16 + 8, y * 16 + 0, (r ? 13 : 12) + (u ? 0 : 1) * 32, 0);
		}

		if (!d && !l) {
			screen.render(x * 16 + 0, y * 16 + 8, 2, 0);
		} else {
			screen.render(x * 16 + 0, y * 16 + 8, (l ? 11 : 12) + (d ? 2 : 1) * 32, 0);
		}
		if (!d && !r) {
			if (!steppedOn)
				screen.render(x * 16 + 8, y * 16 + 8, 3, 0);
			else
				screen.render(x * 16 + 8, y * 16 + 8, 3 + 1 * 32, 0);
		} else {
			screen.render(x * 16 + 8, y * 16 + 8, (r ? 13 : 12) + (d ? 2 : 1) * 32, 0);
		}
	}

	override public function tick(level:Level, x:Int, y:Int) {
		var d = level.getData(x, y);
		if (d > 0) level.setData(x, y, d - 1);
	}

	override public function steppedOn(level:Level, x:Int, y:Int, entity:Entity) {
		if (Std.isOfType(entity, Mob)) {
			level.setData(x, y, 10);
		}
	}

	override public function interact(level:Level, xt:Int, yt:Int, player:Player, item:Item, attackDir:Int):Bool {
		if (Std.isOfType(item, ToolItem)) {
			var tool:ToolItem = cast(item, ToolItem);
			if (tool.type == ToolType.shovel) {
				if (player.payStamina(4 - tool.level)) {
					level.setTile(xt, yt, Tile.dirt, 0);
					level.add(ItemEntity.create(new ResourceItem(Resource.sand), xt * 16 + random.nextInt(10) + 3, yt * 16 + random.nextInt(10) + 3));
					return true;
				}
			}
		}
		return false;
	}
}
