package game.level.tile;

import engine.level.tile.Tile;

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

class FlowerTile extends GrassTile {
	public function new(id:Int) {
		super(id);
		Tile.tiles[id] = this;
		connectsToGrass = true;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		super.render(screen, level, x, y);

		var data = level.getData(x, y);
		var shape = (data / 16) % 2;
		var flowerCol = Color.get(10, level.grassColor, 555, 440);

		if (shape == 0) screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_FLOWER, flowerCol, 0);
		if (shape == 1) screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_FLOWER, flowerCol, 0);
		if (shape == 1) screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_FLOWER, flowerCol, 0);
		if (shape == 0) screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_FLOWER, flowerCol, 0);
	}

	override public function interact(level:Level, x:Int, y:Int, player:Player, item:Item, attackDir:Int):Bool {
		if (Std.isOfType(item, ToolItem)) {
			var tool:ToolItem = cast(item, ToolItem);
			if (tool.type == ToolType.shovel) {
				if (player.payStamina(4 - tool.level)) {
					level.add(ItemEntity.create(new ResourceItem(Resource.flower), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
					level.add(ItemEntity.create(new ResourceItem(Resource.flower), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
					level.setTile(x, y, Tile.grass, 0);
					return true;
				}
			}
		}
		return false;
	}

	override public function hurt(level:Level, x:Int, y:Int, source:Mob, dmg:Int, attackDir:Int) {
		var count = random.nextInt(2) + 1;
		for (i in 0...count) {
			level.add(ItemEntity.create(new ResourceItem(Resource.flower), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
		}
		level.setTile(x, y, Tile.grass, 0);
	}
}
