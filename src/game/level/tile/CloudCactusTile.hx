package game.level.tile;

import engine.level.tile.Tile;

import game.entity.AirWizard;
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
import engine.level.Level;

class CloudCactusTile extends Tile {
	public function new(id:Int) {
		super(id);
		isTall = true;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var color = Color.get(444, 111, 333, 555);
		screen.render(x * 16 + 0, y * 16 + 0, 17 + 1 * 32, color, 0);
		screen.render(x * 16 + 8, y * 16 + 0, 18 + 1 * 32, color, 0);
		screen.render(x * 16 + 0, y * 16 + 8, 17 + 2 * 32, color, 0);
		screen.render(x * 16 + 8, y * 16 + 8, 18 + 2 * 32, color, 0);
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		if (Std.isOfType(e, AirWizard)) return true;
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
			if (damage >= 10) {
				level.setTile(x, y, Tile.cloud, 0);
			} else {
				level.setData(x, y, damage);
			}
		}
	}

	override public function bumpedInto(level:Level, x:Int, y:Int, entity:Entity) {
		if (Std.isOfType(entity, AirWizard)) return;
		entity.hurtTile(this, x, y, 3);
	}
}
