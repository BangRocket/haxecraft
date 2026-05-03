package level.tile;

import entity.Entity;
import entity.ItemEntity;
import entity.Player;
import gfx.Color;
import gfx.Screen;
import item.Item;
import item.ResourceItem;
import item.ToolItem;
import item.ToolType;
import item.resource.Resource;
import level.Level;

class CloudTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var col = Color.get(444, 444, 555, 555);
		var transitionColor = Color.get(333, 444, 555, -1);

		var u = level.getTile(x, y - 1) == Tile.infiniteFall;
		var d = level.getTile(x, y + 1) == Tile.infiniteFall;
		var l = level.getTile(x - 1, y) == Tile.infiniteFall;
		var r = level.getTile(x + 1, y) == Tile.infiniteFall;

		var ul = level.getTile(x - 1, y - 1) == Tile.infiniteFall;
		var dl = level.getTile(x - 1, y + 1) == Tile.infiniteFall;
		var ur = level.getTile(x + 1, y - 1) == Tile.infiniteFall;
		var dr = level.getTile(x + 1, y + 1) == Tile.infiniteFall;

		if (!u && !l) {
			if (!ul)
				screen.render(x * 16 + 0, y * 16 + 0, 17, 0);
			else
				screen.render(x * 16 + 0, y * 16 + 0, 7 + 0 * 32, 3);
		} else {
			screen.render(x * 16 + 0, y * 16 + 0, (l ? 6 : 5) + (u ? 2 : 1) * 32, 3);
		}

		if (!u && !r) {
			if (!ur)
				screen.render(x * 16 + 8, y * 16 + 0, 18, 0);
			else
				screen.render(x * 16 + 8, y * 16 + 0, 8 + 0 * 32, 3);
		} else {
			screen.render(x * 16 + 8, y * 16 + 0, (r ? 4 : 5) + (u ? 2 : 1) * 32, 3);
		}

		if (!d && !l) {
			if (!dl)
				screen.render(x * 16 + 0, y * 16 + 8, 20, 0);
			else
				screen.render(x * 16 + 0, y * 16 + 8, 7 + 1 * 32, 3);
		} else {
			screen.render(x * 16 + 0, y * 16 + 8, (l ? 6 : 5) + (d ? 0 : 1) * 32, 3);
		}
		if (!d && !r) {
			if (!dr)
				screen.render(x * 16 + 8, y * 16 + 8, 19, 0);
			else
				screen.render(x * 16 + 8, y * 16 + 8, 8 + 1 * 32, 3);
		} else {
			screen.render(x * 16 + 8, y * 16 + 8, (r ? 4 : 5) + (d ? 0 : 1) * 32, 3);
		}
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return true;
	}

	override public function interact(level:Level, xt:Int, yt:Int, player:Player, item:Item, attackDir:Int):Bool {
		if (Std.isOfType(item, ToolItem)) {
			var tool:ToolItem = cast(item, ToolItem);
			if (tool.type == ToolType.shovel) {
				if (player.payStamina(5)) {
					// level.setTile(xt, yt, Tile.infiniteFall, 0);
					var count = random.nextInt(2) + 1;
					for (i in 0...count) {
						level.add(ItemEntity.create(new ResourceItem(Resource.cloud), xt * 16 + random.nextInt(10) + 3, yt * 16 + random.nextInt(10) + 3));
					}
					return true;
				}
			}
		}
		return false;
	}
}
