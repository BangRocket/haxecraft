package entity;

import gfx.Color;
import gfx.Screen;
import item.Item;
import sound.Sound;

class ItemEntity extends Entity {
	private var lifeTime:Int;
	var walkDist:Int = 0;
	var dir:Int = 0;
	public var hurtTime:Int = 0;
	var xKnockback:Int;
	var yKnockback:Int;
	public var xa:Float;
	public var ya:Float;
	public var za:Float;
	public var xx:Float;
	public var yy:Float;
	public var zz:Float;
	public var item:Item;
	private var time:Int = 0;

	public function new(item:Item, x:Int, y:Int) {
		super();
		this.item = item;
		xx = this.x = x;
		yy = this.y = y;
		xr = 3;
		yr = 3;

		zz = 2;
		xa = random.nextGaussian() * 0.3;
		ya = random.nextGaussian() * 0.2;
		za = random.nextFloat() * 0.7 + 1;

		lifeTime = 60 * 10 + random.nextInt(60);
	}

	override public function tick() {
		time++;
		if (time >= lifeTime) {
			remove();
			return;
		}
		xx += xa;
		yy += ya;
		zz += za;
		if (zz < 0) {
			zz = 0;
			za *= -0.5;
			xa *= 0.6;
			ya *= 0.6;
		}
		za -= 0.15;
		var ox = x;
		var oy = y;
		var nx = Std.int(xx);
		var ny = Std.int(yy);
		var expectedx = nx - x;
		var expectedy = ny - y;
		move(nx - x, ny - y);
		var gotx = x - ox;
		var goty = y - oy;
		xx += gotx - expectedx;
		yy += goty - expectedy;

		if (hurtTime > 0) hurtTime--;
	}

	override public function isBlockableBy(mob:Mob):Bool {
		return false;
	}

	override public function render(screen:Screen) {
		if (time >= lifeTime - 6 * 20) {
			if (Std.int(time / 6) % 2 == 0) return;
		}
		screen.render(x - 4, y - 4, item.getSprite(), 0);
		screen.render(x - 4, y - 4 - Std.int(zz), item.getSprite(), 0);
	}

	override function touchedBy(entity:Entity) {
		if (time > 30) entity.touchItem(this);
	}

	public function take(player:Player) {
		Sound.pickup.play();
		player.score++;
		item.onTake(this);
		remove();
	}
}
