package engine.entity.particle;

import engine.entity.Entity;
import engine.gfx.Color;
import engine.gfx.Screen;
import engine.sound.Sound;
import game.SpriteNames;

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
		screen.renderSprite(x - 8, y - 8, SpriteNames.UI_SMASH_PARTICLE, col, 2);
		screen.renderSprite(x - 0, y - 8, SpriteNames.UI_SMASH_PARTICLE, col, 3);
		screen.renderSprite(x - 8, y - 0, SpriteNames.UI_SMASH_PARTICLE, col, 0);
		screen.renderSprite(x - 0, y - 0, SpriteNames.UI_SMASH_PARTICLE, col, 1);
	}
}
