package com.mojang.ld22.entity;

import com.mojang.ld22.gfx.Color;

class Lantern extends Furniture {
	public function new() {
		super("Lantern");
		col = Color.get(-1, 0, 111, 555);
		sprite = 5;
		xr = 3;
		yr = 2;
	}

	override public function getLightRadius():Int {
		return 8;
	}
}
