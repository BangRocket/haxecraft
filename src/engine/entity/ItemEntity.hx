package engine.entity;

import engine.gfx.Color;
import engine.gfx.Screen;
import engine.item.Item;
import engine.sound.Sound;
import game.entity.Player;

class ItemEntity extends Entity {
	static var pool:Array<ItemEntity> = [];

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

	public function new() {
		super();
	}

	public static function create(item:Item, x:Int, y:Int):ItemEntity {
		var e = pool.length > 0 ? pool.pop() : new ItemEntity();
		e.removed = false;
		e.item = item;
		e.x = x;
		e.y = y;
		e.xx = x;
		e.yy = y;
		e.xr = 3;
		e.yr = 3;
		e.zz = 2;
		e.xa = e.random.nextGaussian() * 0.3;
		e.ya = e.random.nextGaussian() * 0.2;
		e.za = e.random.nextFloat() * 0.7 + 1;
		e.lifeTime = 60 * 10 + e.random.nextInt(60);
		e.time = 0;
		e.hurtTime = 0;
		e.walkDist = 0;
		e.dir = 0;
		e.xKnockback = 0;
		e.yKnockback = 0;
		return e;
	}

	override public function onRemovedFromLevel() {
		pool.push(this);
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
		screen.render(x - 4, y - 4, item.getSprite(), Color.get(-1, 0, 0, 0), 0);
		screen.render(x - 4, y - 4 - Std.int(zz), item.getSprite(), item.getColor(), 0);
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
