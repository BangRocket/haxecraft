package com.mojang.ld22.level.tile;

import com.mojang.ld22.entity.Entity;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.level.Level;

class StoneTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		var rc1 = 111;
		var rc2 = 333;
		var rc3 = 555;
		screen.render(x * 16 + 0, y * 16 + 0, 32, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
		screen.render(x * 16 + 8, y * 16 + 0, 32, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
		screen.render(x * 16 + 0, y * 16 + 8, 32, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
		screen.render(x * 16 + 8, y * 16 + 8, 32, Color.get(rc1, level.dirtColor, rc2, rc3), 0);
	}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return false;
	}
}
