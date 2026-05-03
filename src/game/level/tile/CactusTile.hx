package game.level.tile;

import engine.level.tile.Tile;

import engine.entity.Entity;
import engine.entity.ItemEntity;
import engine.entity.Mob;
import engine.entity.particle.SmashParticle;
import engine.entity.particle.TextParticle;
import engine.gfx.Color;
import engine.gfx.Screen;
import game.item.ResourceItem;
import engine.item.resource.Resource;
import engine.level.Level;

class CactusTile extends Tile {
	public function new(id:Int) {
		super(id);
		connectsToSand = true;
		isTall = true;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var col = Color.get(20, 40, 50, level.sandColor);
		screen.render(x * 16 + 0, y * 16 + 0, 8 + 2 * 32, 0);
		screen.render(x * 16 + 8, y * 16 + 0, 9 + 2 * 32, 0);
		screen.render(x * 16 + 0, y * 16 + 8, 8 + 3 * 32, 0);
		screen.render(x * 16 + 8, y * 16 + 8, 9 + 3 * 32, 0);
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return false;
	}

	override public function hurt(level:Level, x:Int, y:Int, source:Mob, dmg:Int, attackDir:Int) {
		var damage = level.getData(x, y) + dmg;
		level.add(SmashParticle.create(x * 16 + 8, y * 16 + 8));
		level.add(TextParticle.create("" + dmg, x * 16 + 8, y * 16 + 8, Color.get(-1, 500, 500, 500)));
		if (damage >= 10) {
			var count = random.nextInt(2) + 1;
			for (i in 0...count) {
				level.add(ItemEntity.create(new ResourceItem(Resource.cactusFlower), x * 16 + random.nextInt(10) + 3, y * 16 + random.nextInt(10) + 3));
			}
			level.setTile(x, y, Tile.sand, 0);
		} else {
			level.setData(x, y, damage);
		}
	}

	override public function bumpedInto(level:Level, x:Int, y:Int, entity:Entity) {
		entity.hurtTile(this, x, y, 1);
	}

	override public function tick(level:Level, xt:Int, yt:Int) {
		var damage = level.getData(xt, yt);
		if (damage > 0) level.setData(xt, yt, damage - 1);
	}
}
