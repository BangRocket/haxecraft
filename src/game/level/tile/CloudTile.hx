package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.entity.ItemEntity;
import game.entity.Player;
import engine.gfx.Color;
import engine.gfx.Screen;
import game.SpriteNames;
import engine.item.Item;
import game.item.ResourceItem;
import game.item.ToolItem;
import engine.item.ToolType;
import engine.item.resource.Resource;
import engine.level.Level;

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
				screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_CLOUD[0], col, 0);
			else
				screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_STONE_CORNER_UL, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.edgeStoneTL(l, u), transitionColor, 3);
		}

		if (!u && !r) {
			if (!ur)
				screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_CLOUD[1], col, 0);
			else
				screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_STONE_CORNER_UR, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.edgeStoneTR(r, u), transitionColor, 3);
		}

		if (!d && !l) {
			if (!dl)
				screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_CLOUD[2], col, 0);
			else
				screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_STONE_CORNER_DL, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.edgeStoneBL(l, d), transitionColor, 3);
		}
		if (!d && !r) {
			if (!dr)
				screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_CLOUD[3], col, 0);
			else
				screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_STONE_CORNER_DR, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.edgeStoneBR(r, d), transitionColor, 3);
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
