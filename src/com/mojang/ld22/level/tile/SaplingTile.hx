package com.mojang.ld22.level.tile;

import com.mojang.ld22.entity.Mob;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.level.Level;

class SaplingTile extends Tile {
	var onType:Tile;
	var growsTo:Tile;

	public function new(id:Int, onType:Tile, growsTo:Tile) {
		super(id);
		this.onType = onType;
		this.growsTo = growsTo;
		connectsToSand = onType.connectsToSand;
		connectsToGrass = onType.connectsToGrass;
		connectsToWater = onType.connectsToWater;
		connectsToLava = onType.connectsToLava;
	}

	override public function render(screen:Screen, level:Level, x:Int, y:Int) {
		onType.render(screen, level, x, y);
		var col = Color.get(10, 40, 50, -1);
		screen.render(x * 16 + 4, y * 16 + 4, 11 + 3 * 32, col, 0);
	}

	override public function tick(level:Level, x:Int, y:Int) {
		var age = level.getData(x, y) + 1;
		if (age > 100) {
			level.setTile(x, y, growsTo, 0);
		} else {
			level.setData(x, y, age);
		}
	}

	override public function hurt(level:Level, x:Int, y:Int, source:Mob, dmg:Int, attackDir:Int) {
		level.setTile(x, y, onType, 0);
	}
}
