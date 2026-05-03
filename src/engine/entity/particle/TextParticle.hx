package engine.entity.particle;

import engine.entity.Entity;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;

class TextParticle extends Entity {
	static var pool:Array<TextParticle> = [];

	private var msg:String;
	private var col:Int;
	private var time:Int = 0;
	public var xa:Float;
	public var ya:Float;
	public var za:Float;
	public var xx:Float;
	public var yy:Float;
	public var zz:Float;

	public function new() {
		super();
	}

	public static function create(msg:String, x:Int, y:Int, col:Int):TextParticle {
		var p = pool.length > 0 ? pool.pop() : new TextParticle();
		p.removed = false;
		p.msg = msg;
		p.col = col;
		p.x = x;
		p.y = y;
		p.xx = x;
		p.yy = y;
		p.zz = 2;
		p.xa = p.random.nextGaussian() * 0.3;
		p.ya = p.random.nextGaussian() * 0.2;
		p.za = p.random.nextFloat() * 0.7 + 2;
		p.time = 0;
		return p;
	}

	override public function onRemovedFromLevel() {
		pool.push(this);
	}

	override public function tick() {
		time++;
		if (time > 60) {
			remove();
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
		x = Std.int(xx);
		y = Std.int(yy);
	}

	override public function render(screen:Screen) {
		Font.draw(msg, screen, x - msg.length * 4 + 1, y - Std.int(zz) + 1, Color.get(-1, 0, 0, 0));
		Font.draw(msg, screen, x - msg.length * 4, y - Std.int(zz), col);
	}
}
