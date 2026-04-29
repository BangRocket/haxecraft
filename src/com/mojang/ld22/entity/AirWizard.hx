package com.mojang.ld22.entity;

import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.item.ResourceItem;
import com.mojang.ld22.item.resource.Resource;
import com.mojang.ld22.sound.Sound;

class AirWizard extends Mob {
	var xa:Int;
	var ya:Int;
	var randomWalkTime:Int = 0;
	var attackDelay:Int = 0;
	var attackTime:Int = 0;
	var attackType:Int = 0;

	public function new() {
		super();
		x = random.nextInt(64 * 16);
		y = random.nextInt(64 * 16);
		health = maxHealth = 2000;
	}

	override public function tick() {
		super.tick();

		if (attackDelay > 0) {
			dir = Std.int((attackDelay - 45) / 4) % 4;
			dir = (dir * 2 % 4) + Std.int(dir / 2);
			if (attackDelay < 45) {
				dir = 0;
			}
			attackDelay--;
			if (attackDelay == 0) {
				attackType = 0;
				if (health < 1000) attackType = 1;
				if (health < 200) attackType = 2;
				attackTime = 60 * 2;
			}
			return;
		}

		if (attackTime > 0) {
			attackTime--;
			var dir = attackTime * 0.25 * (attackTime % 2 * 2 - 1);
			var speed = (0.7) + attackType * 0.2;
			level.add(new Spark(this, Math.cos(dir) * speed, Math.sin(dir) * speed));
			return;
		}

		if (level.player != null && randomWalkTime == 0) {
			var xd = level.player.x - x;
			var yd = level.player.y - y;
			if (xd * xd + yd * yd < 32 * 32) {
				xa = 0;
				ya = 0;
				if (xd < 0) xa = 1;
				if (xd > 0) xa = -1;
				if (yd < 0) ya = 1;
				if (yd > 0) ya = -1;
			} else if (xd * xd + yd * yd > 80 * 80) {
				xa = 0;
				ya = 0;
				if (xd < 0) xa = -1;
				if (xd > 0) xa = 1;
				if (yd < 0) ya = -1;
				if (yd > 0) ya = 1;
			}
		}

		var speed = (tickTime % 4) == 0 ? 0 : 1;
		if (!move(xa * speed, ya * speed) || random.nextInt(100) == 0) {
			randomWalkTime = 30;
			xa = (random.nextInt(3) - 1);
			ya = (random.nextInt(3) - 1);
		}
		if (randomWalkTime > 0) {
			randomWalkTime--;
			if (level.player != null && randomWalkTime == 0) {
				var xd = level.player.x - x;
				var yd = level.player.y - y;
				if (random.nextInt(4) == 0 && xd * xd + yd * yd < 50 * 50) {
					if (attackDelay == 0 && attackTime == 0) {
						attackDelay = 60 * 2;
					}
				}
			}
		}
	}

	override function doHurt(damage:Int, attackDir:Int) {
		super.doHurt(damage, attackDir);
		if (attackDelay == 0 && attackTime == 0) {
			attackDelay = 60 * 2;
		}
	}

	override public function render(screen:Screen) {
		var xt = 8;
		var yt = 14;

		var flip1 = (walkDist >> 3) & 1;
		var flip2 = (walkDist >> 3) & 1;

		if (dir == 1) {
			xt += 2;
		}
		if (dir > 1) {
			flip1 = 0;
			flip2 = ((walkDist >> 4) & 1);
			if (dir == 2) {
				flip1 = 1;
			}
			xt += 4 + ((walkDist >> 3) & 1) * 2;
		}

		var xo = x - 8;
		var yo = y - 11;

		var col1 = Color.get(-1, 100, 500, 555);
		var col2 = Color.get(-1, 100, 500, 532);
		if (health < 200) {
			if (Std.int(tickTime / 3) % 2 == 0) {
				col1 = Color.get(-1, 500, 100, 555);
				col2 = Color.get(-1, 500, 100, 532);
			}
		} else if (health < 1000) {
			if (Std.int(tickTime / 5) % 4 == 0) {
				col1 = Color.get(-1, 500, 100, 555);
				col2 = Color.get(-1, 500, 100, 532);
			}
		}
		if (hurtTime > 0) {
			col1 = Color.get(-1, 555, 555, 555);
			col2 = Color.get(-1, 555, 555, 555);
		}

		screen.render(xo + 8 * flip1, yo + 0, xt + yt * 32, col1, flip1);
		screen.render(xo + 8 - 8 * flip1, yo + 0, xt + 1 + yt * 32, col1, flip1);
		screen.render(xo + 8 * flip2, yo + 8, xt + (yt + 1) * 32, col2, flip2);
		screen.render(xo + 8 - 8 * flip2, yo + 8, xt + 1 + (yt + 1) * 32, col2, flip2);
	}

	override function touchedBy(entity:Entity) {
		if (Std.isOfType(entity, Player)) {
			entity.hurt(this, 3, dir);
		}
	}

	override function die() {
		super.die();
		if (level.player != null) {
			level.player.score += 1000;
			level.player.gameWon();
		}
		Sound.bossdeath.play();
	}
}
