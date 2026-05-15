package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.entity.ItemEntity;
import engine.entity.Mob;
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

class WheatTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var age = level.getData(x, y);
		var col = Color.get(level.dirtColor - 121, level.dirtColor - 11, level.dirtColor, 50);
		var icon = Std.int(age / 10);
		if (icon >= 3) {
			col = Color.get(level.dirtColor - 121, level.dirtColor - 11, 50 + (icon) * 100, 40 + (icon - 3) * 2 * 100);
			if (age == 50) {
				col = Color.get(0, 0, 50 + (icon) * 100, 40 + (icon - 3) * 2 * 100);
			}
			icon = 3;
		}

		screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_WHEAT[icon], col, 0);
		screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_WHEAT[icon], col, 0);
		screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_WHEAT[icon], col, 1);
		screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_WHEAT[icon], col, 1);
	}

	override public function tick(level:Level, xt:Int, yt:Int) {
		if (random.nextInt(2) == 0) return;

		var age = level.getData(xt, yt);
		if (age < 50) level.setData(xt, yt, age + 1);
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

	override public function steppedOn(level:Level, xt:Int, yt:Int, entity:Entity) {
		if (random.nextInt(60) != 0) return;
		if (level.getData(xt, yt) < 2) return;
		harvest(level, xt, yt);
	}

	override public function hurt(level:Level, x:Int, y:Int, source:Mob, dmg:Int, attackDir:Int) {
		harvest(level, x, y);
	}

	function harvest(level:Level, x:Int, y:Int) {
		var age = level.getData(x, y);

		var count = random.nextInt(2);
		for (i in 0...count) {
			level.add(ItemEntity.create(new ResourceItem(Resource.seeds), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
		}

		count = 0;
		if (age == 50) {
			count = random.nextInt(3) + 2;
		} else if (age >= 40) {
			count = random.nextInt(2) + 1;
		}
		for (i in 0...count) {
			level.add(ItemEntity.create(new ResourceItem(Resource.wheat), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
		}

		level.setTile(x, y, Tile.dirt, 0);
	}
}
