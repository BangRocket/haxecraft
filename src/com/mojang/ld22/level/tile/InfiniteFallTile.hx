package com.mojang.ld22.level.tile;

import com.mojang.ld22.entity.AirWizard;
import com.mojang.ld22.entity.Entity;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.level.Level;

class InfiniteFallTile extends Tile {
	public function new(id:Int) {
		super(id);
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {}

	override public function tick(level:Level, xt:Int, yt:Int) {}

	override public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		if (Std.isOfType(e, AirWizard)) return true;
		return false;
	}
}
