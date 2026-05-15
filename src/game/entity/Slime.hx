package game.entity;

import engine.entity.Entity;

import engine.entity.Mob;
import engine.entity.ItemEntity;

import engine.gfx.Color;
import engine.gfx.Screen;
import game.SpriteNames;
import game.item.ResourceItem;
import engine.item.resource.Resource;

class Slime extends Mob {
	var xa:Int;
	var ya:Int;
	var jumpTime:Int = 0;
	var lvl:Int;

	public function new(lvl:Int) {
		super();
		this.lvl = lvl;
		x = random.nextInt(64 * 16);
		y = random.nextInt(64 * 16);
		health = maxHealth = lvl * lvl * 5;
	}

	override public function tick() {
		super.tick();

		var speed = 1;
		if (!move(xa * speed, ya * speed) || random.nextInt(40) == 0) {
			if (jumpTime <= -10) {
				xa = (random.nextInt(3) - 1);
				ya = (random.nextInt(3) - 1);

				if (level.player != null) {
					var xd = level.player.x - x;
					var yd = level.player.y - y;
					if (xd * xd + yd * yd < 50 * 50) {
						if (xd < 0) xa = -1;
						if (xd > 0) xa = 1;
						if (yd < 0) ya = -1;
						if (yd > 0) ya = 1;
					}

				}

				if (xa != 0 || ya != 0) jumpTime = 10;
			}
		}

		jumpTime--;
		if (jumpTime == 0) {
			xa = ya = 0;
		}
	}

	override function die() {
		super.die();

		var count = random.nextInt(2) + 1;
		for (i in 0...count) {
			level.add(ItemEntity.create(new ResourceItem(Resource.slime), x + random.nextInt(11) - 5, y + random.nextInt(11) - 5));
		}

		if (level.player != null) {
			level.player.score += 25 * lvl;
		}
	}

	override public function render(screen:Screen) {
		var xt = 0;
		var yt = 18;

		var xo = x - 8;
		var yo = y - 11;

		if (jumpTime > 0) {
			xt += 2;
			yo -= 4;
		}

		var col = Color.get(-1, 10, 252, 555);
		if (lvl == 2) col = Color.get(-1, 100, 522, 555);
		if (lvl == 3) col = Color.get(-1, 111, 444, 555);
		if (lvl == 4) col = Color.get(-1, 0, 111, 224);

		if (hurtTime > 0) {
			col = Color.get(-1, 555, 555, 555);
		}

		screen.renderSprite(xo + 0, yo + 0, SpriteNames.monsterRawTile(xt + yt * 32), col, 0);
		screen.renderSprite(xo + 8, yo + 0, SpriteNames.monsterRawTile(xt + 1 + yt * 32), col, 0);
		screen.renderSprite(xo + 0, yo + 8, SpriteNames.monsterRawTile(xt + (yt + 1) * 32), col, 0);
		screen.renderSprite(xo + 8, yo + 8, SpriteNames.monsterRawTile(xt + 1 + (yt + 1) * 32), col, 0);
	}

	override function touchedBy(entity:Entity) {
		if (Std.isOfType(entity, Player)) {
			entity.hurt(this, lvl, dir);
		}
	}
}
