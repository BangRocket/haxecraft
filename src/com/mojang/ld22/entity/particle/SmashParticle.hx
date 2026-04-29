package com.mojang.ld22.entity.particle;

import com.mojang.ld22.entity.Entity;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.sound.Sound;

class SmashParticle extends Entity {
	private var time:Int = 0;

	public function new(x:Int, y:Int) {
		super();
		this.x = x;
		this.y = y;
		Sound.monsterHurt.play();
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
