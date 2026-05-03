package engine.entity.particle;

import engine.entity.Entity;
import engine.gfx.Color;
import engine.gfx.Screen;
import engine.sound.Sound;

class SmashParticle extends Entity {
	static var pool:Array<SmashParticle> = [];

	private var time:Int = 0;

	public function new() {
		super();
	}

	public static function create(x:Int, y:Int):SmashParticle {
		var p = pool.length > 0 ? pool.pop() : new SmashParticle();
		p.removed = false;
		p.x = x;
		p.y = y;
		p.time = 0;
		Sound.monsterHurt.play();
		return p;
	}

	override public function onRemovedFromLevel() {
		pool.push(this);
	}

	override public function tick() {
		time++;
		if (time > 10) {
			remove();
		}
	}

	override public function render(screen:Screen) {
		var col = Color.get(-1, 555, 555, 555);
		screen.render(x - 8, y - 8, 5 + 12 * 32, col, 2);
		screen.render(x - 0, y - 8, 5 + 12 * 32, col, 3);
		screen.render(x - 8, y - 0, 5 + 12 * 32, col, 0);
		screen.render(x - 0, y - 0, 5 + 12 * 32, col, 1);
	}
}
