package level.tile;

import entity.Entity;
import entity.ItemEntity;
import entity.Mob;
import entity.Player;
import entity.particle.SmashParticle;
import entity.particle.TextParticle;
import gfx.Color;
import gfx.Screen;
import item.Item;
import item.ResourceItem;
import item.ToolItem;
import item.ToolType;
import item.resource.Resource;
import level.Level;

class HardRockTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var col = Color.get(334, 334, 223, 223);
		var transitionColor = Color.get(1, 334, 445, level.dirtColor);

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
				screen.render(x * 16 + 0, y * 16 + 0, 0, 0);
			else
				screen.render(x * 16 + 0, y * 16 + 0, 7 + 0 * 32, 3);
		} else {
			screen.render(x * 16 + 0, y * 16 + 0, (l ? 6 : 5) + (u ? 2 : 1) * 32, 3);
		}

		if (!u && !r) {
			if (!ur)
				screen.render(x * 16 + 8, y * 16 + 0, 1, 0);
			else
				screen.render(x * 16 + 8, y * 16 + 0, 8 + 0 * 32, 3);
		} else {
			screen.render(x * 16 + 8, y * 16 + 0, (r ? 4 : 5) + (u ? 2 : 1) * 32, 3);
		}

		if (!d && !l) {
			if (!dl)
				screen.render(x * 16 + 0, y * 16 + 8, 2, 0);
			else
				screen.render(x * 16 + 0, y * 16 + 8, 7 + 1 * 32, 3);
		} else {
			screen.render(x * 16 + 0, y * 16 + 8, (l ? 6 : 5) + (d ? 0 : 1) * 32, 3);
		}
		if (!d && !r) {
			if (!dr)
				screen.render(x * 16 + 8, y * 16 + 8, 3, 0);
			else
				screen.render(x * 16 + 8, y * 16 + 8, 8 + 1 * 32, 3);
		} else {
			screen.render(x * 16 + 8, y * 16 + 8, (r ? 4 : 5) + (d ? 0 : 1) * 32, 3);
		}
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return false;
	}

	override public function hurt(level:Level, x:Int, y:Int, source:Mob, dmg:Int, attackDir:Int) {
		hurtTileDamage(level, x, y, 0);
	}

	override public function interact(level:Level, xt:Int, yt:Int, player:Player, item:Item, attackDir:Int):Bool {
		if (Std.isOfType(item, ToolItem)) {
			var tool:ToolItem = cast(item, ToolItem);
			if (tool.type == ToolType.pickaxe && tool.level == 4) {
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
		if (damage >= 200) {
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
