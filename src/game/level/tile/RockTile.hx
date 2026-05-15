package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.entity.ItemEntity;
import engine.entity.Mob;
import game.entity.Player;
import engine.entity.particle.SmashParticle;
import engine.entity.particle.TextParticle;
import engine.gfx.Color;
import engine.gfx.Screen;
import game.SpriteNames;
import engine.item.Item;
import game.item.ResourceItem;
import game.item.ToolItem;
import engine.item.ToolType;
import engine.item.resource.Resource;
import engine.level.Level;

class RockTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var col = Color.get(444, 444, 333, 333);
		var transitionColor = Color.get(111, 444, 555, level.dirtColor);

		var u = level.getTile(x, y - 1) != this;
		var d = level.getTile(x, y + 1) != this;
		var l = level.getTile(x - 1, y) != this;
		var r = level.getTile(x + 1, y) != this;

		var ul = level.getTile(x - 1, y - 1) != this;
		var dl = level.getTile(x - 1, y + 1) != this;
		var ur = level.getTile(x + 1, y - 1) != this;
		var dr = level.getTile(x + 1, y + 1) != this;

		if (!u && !l) {
			if (!ul)
				screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_BASE[0], col, 0);
			else
				screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.TERRAIN_STONE_CORNER_UL, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 0, SpriteNames.edgeStoneTL(l, u), transitionColor, 3);
		}

		if (!u && !r) {
			if (!ur)
				screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_BASE[1], col, 0);
			else
				screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.TERRAIN_STONE_CORNER_UR, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 0, SpriteNames.edgeStoneTR(r, u), transitionColor, 3);
		}

		if (!d && !l) {
			if (!dl)
				screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_BASE[2], col, 0);
			else
				screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.TERRAIN_STONE_CORNER_DL, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 0, y * 16 + 8, SpriteNames.edgeStoneBL(l, d), transitionColor, 3);
		}
		if (!d && !r) {
			if (!dr)
				screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_BASE[3], col, 0);
			else
				screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.TERRAIN_STONE_CORNER_DR, transitionColor, 3);
		} else {
			screen.renderSprite(x * 16 + 8, y * 16 + 8, SpriteNames.edgeStoneBR(r, d), transitionColor, 3);
		}
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return false;
	}

	override public function hurt(level:Level, x:Int, y:Int, source:Mob, dmg:Int, attackDir:Int) {
		hurtTileDamage(level, x, y, dmg);
	}

	override public function interact(level:Level, xt:Int, yt:Int, player:Player, item:Item, attackDir:Int):Bool {
		if (Std.isOfType(item, ToolItem)) {
			var tool:ToolItem = cast(item, ToolItem);
			if (tool.type == ToolType.pickaxe) {
				if (player.payStamina(4 - tool.level)) {
					hurtTileDamage(level, xt, yt, random.nextInt(10) + (tool.level) * 5 + 10);
					return true;
				}
			}
		}
		return false;
	}

	public function hurtTileDamage(level:Level, x:Int, y:Int, dmg:Int) {
		var damage = level.getData(x, y) + dmg;
		level.add(SmashParticle.create(x * 16 + 8, y * 16 + 8));
		level.add(TextParticle.create("" + dmg, x * 16 + 8, y * 16 + 8, Color.get(-1, 500, 500, 500)));
		if (damage >= 50) {
			var count = random.nextInt(4) + 1;
			for (i in 0...count) {
				level.add(ItemEntity.create(new ResourceItem(Resource.stone), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
			}
			count = random.nextInt(2);
			for (i in 0...count) {
				level.add(ItemEntity.create(new ResourceItem(Resource.coal), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
			}
			level.setTile(x, y, Tile.dirt, 0);
		} else {
			level.setData(x, y, damage);
		}
	}

	override public function tick(level:Level, xt:Int, yt:Int) {
		var damage = level.getData(xt, yt);
		if (damage > 0) level.setData(xt, yt, damage - 1);
	}
}
