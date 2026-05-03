package entity;

import entity.particle.TextParticle;
import gfx.Color;
import level.Level;
import level.tile.Tile;
import sound.Sound;

class Mob extends Entity {
	var walkDist:Int = 0;
	public var dir:Int = 0;
	public var hurtTime:Int = 0;
	var xKnockback:Int;
	var yKnockback:Int;
	public var maxHealth:Int = 10;
	public var health:Int;
	public var swimTimer:Int = 0;
	public var tickTime:Int = 0;

	public function new() {
		super();
		x = y = 8;
		xr = 4;
		yr = 3;
		health = maxHealth;
	}

	override public function tick() {
		tickTime++;
		if (level.getTile(x >> 4, y >> 4) == Tile.lava) {
			hurt(this, 4, dir ^ 1);
		}

		if (health <= 0) {
			die();
		}
		if (hurtTime > 0) hurtTime--;
	}

	function die() {
		remove();
	}

	override public function move(xa:Int, ya:Int):Bool {
		if (isSwimming()) {
			if (swimTimer++ % 2 == 0) return true;
		}
		if (xKnockback < 0) {
			move2(-1, 0);
			xKnockback++;
		}
		if (xKnockback > 0) {
			move2(1, 0);
			xKnockback--;
		}
		if (yKnockback < 0) {
			move2(0, -1);
			yKnockback++;
		}
		if (yKnockback > 0) {
			move2(0, 1);
			yKnockback--;
		}
		if (hurtTime > 0) return true;
		if (xa != 0 || ya != 0) {
			walkDist++;
			if (xa < 0) dir = 2;
			if (xa > 0) dir = 3;
			if (ya < 0) dir = 1;
			if (ya > 0) dir = 0;
		}
		return super.move(xa, ya);
	}

	function isSwimming():Bool {
		var tile = level.getTile(x >> 4, y >> 4);
		return tile == Tile.water || tile == Tile.lava;
	}

	override public function blocks(e:Entity):Bool {
		return e.isBlockableBy(this);
	}

	override public function hurtTile(tile:Tile, x:Int, y:Int, damage:Int) {
		var attackDir = dir ^ 1;
		doHurt(damage, attackDir);
	}

	override public function hurt(mob:Mob, damage:Int, attackDir:Int) {
		doHurt(damage, attackDir);
	}

	public function heal(heal:Int) {
		if (hurtTime > 0) return;

		level.add(TextParticle.create("" + heal, x, y, Color.get(-1, 50, 50, 50)));
		health += heal;
		if (health > maxHealth) health = maxHealth;
	}

	function doHurt(damage:Int, attackDir:Int) {
		if (hurtTime > 0) return;

		if (level.player != null) {
			var xd = level.player.x - x;
			var yd = level.player.y - y;
			if (xd * xd + yd * yd < 80 * 80) {
				Sound.monsterHurt.play();
			}
		}
		level.add(TextParticle.create("" + damage, x, y, Color.get(-1, 500, 500, 500)));
		health -= damage;
		if (attackDir == 0) yKnockback = 6;
		if (attackDir == 1) yKnockback = -6;
		if (attackDir == 2) xKnockback = -6;
		if (attackDir == 3) xKnockback = 6;
		hurtTime = 10;
	}

	public function findStartPos(level:Level):Bool {
		var x = random.nextInt(level.w);
		var y = random.nextInt(level.h);
		var xx = x * 16 + 8;
		var yy = y * 16 + 8;

		if (level.player != null) {
			var xd = level.player.x - xx;
			var yd = level.player.y - yy;
			if (xd * xd + yd * yd < 80 * 80) return false;
		}

		var r = level.monsterDensity * 16;
		if (level.getEntities(xx - r, yy - r, xx + r, yy + r).length > 0) return false;

		if (level.getTile(x, y).mayPass(level, x, y, this)) {
			this.x = xx;
			this.y = yy;
			return true;
		}

		return false;
	}
}
