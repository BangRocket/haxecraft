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
import engine.item.Item;
import game.item.ResourceItem;
import game.item.ToolItem;
import engine.item.ToolType;
import engine.item.resource.Resource;
import engine.level.Level;

class OreTile extends Tile {
	var getDrop:Void->Resource;
	var color:Int;

	public function new(id:Int, getDrop:Void->Resource) {
		super(id);
		this.getDrop = getDrop;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var toDrop = getDrop();
		color = (toDrop.color & 0xffffff00) + Color.get(level.dirtColor);
		screen.render(x * 16 + 0, y * 16 + 0, 17 + 1 * 32, 0);
		screen.render(x * 16 + 8, y * 16 + 0, 18 + 1 * 32, 0);
		screen.render(x * 16 + 0, y * 16 + 8, 17 + 2 * 32, 0);
		screen.render(x * 16 + 8, y * 16 + 8, 18 + 2 * 32, 0);
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
			if (tool.type == ToolType.pickaxe) {
				if (player.payStamina(6 - tool.level)) {
					hurtTileDamage(level, xt, yt, 1);
					return true;
				}
			}
		}
		return false;
	}

	public function hurtTileDamage(level:Level, x:Int, y:Int, dmg:Int) {
		var damage = level.getData(x, y) + 1;
		level.add(SmashParticle.create(x * 16 + 8, y * 16 + 8));
		level.add(TextParticle.create("" + dmg, x * 16 + 8, y * 16 + 8, Color.get(-1, 500, 500, 500)));
		if (dmg > 0) {
			var count = random.nextInt(2);
			if (damage >= random.nextInt(10) + 3) {
				level.setTile(x, y, Tile.dirt, 0);
				count += 2;
			} else {
				level.setData(x, y, damage);
			}
			for (i in 0...count) {
				level.add(ItemEntity.create(new ResourceItem(getDrop()), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
			}
		}
	}

	override public function bumpedInto(level:Level, x:Int, y:Int, entity:Entity) {
		entity.hurtTile(this, x, y, 3);
	}
}
