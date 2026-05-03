package game.entity;

import engine.entity.Entity;
import engine.entity.Mob;

import engine.gfx.Color;
import engine.gfx.Screen;

class Spark extends Entity {
	private var lifeTime:Int;
	public var xa:Float;
	public var ya:Float;
	public var xx:Float;
	public var yy:Float;
	private var time:Int;
	var owner:AirWizard;

	public function new(owner:AirWizard, xa:Float, ya:Float) {
		super();
		this.owner = owner;
		xx = this.x = owner.x;
		yy = this.y = owner.y;
		xr = 0;
		yr = 0;

		this.xa = xa;
		this.ya = ya;

		lifeTime = 60 * 10 + random.nextInt(30);
	}

	override public function tick() {
		time++;
		if (time >= lifeTime) {
			remove();
			return;
		}
		xx += xa;
		yy += ya;
		x = Std.int(xx);
		y = Std.int(yy);
		var toHit = level.getEntities(x, y, x, y);
		for (i in 0...toHit.length) {
			var e = toHit[i];
			if (Std.isOfType(e, Mob) && !Std.isOfType(e, AirWizard)) {
				e.hurt(owner, 1, cast(e, Mob).dir ^ 1);
			}
		}
	}

	override public function isBlockableBy(mob:Mob):Bool {
		return false;
	}

	override public function render(screen:Screen) {
		if (time >= lifeTime - 6 * 20) {
			if (Std.int(time / 6) % 2 == 0) return;
		}

		var xt = 8;
		var yt = 13;

		screen.render(x - 4, y - 4 - 2, xt + yt * 32, Color.get(-1, 555, 555, 555), random.nextInt(4));
		screen.render(x - 4, y - 4 + 2, xt + yt * 32, Color.get(-1, 0, 0, 0), random.nextInt(4));
	}
}
