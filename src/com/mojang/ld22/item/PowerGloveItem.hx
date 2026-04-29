package com.mojang.ld22.item;

import com.mojang.ld22.entity.Entity;
import com.mojang.ld22.entity.Furniture;
import com.mojang.ld22.entity.Player;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Font;
import com.mojang.ld22.gfx.Screen;

class PowerGloveItem extends Item {
	override public function getColor():Int {
		return Color.get(-1, 100, 320, 430);
	}

	override public function getSprite():Int {
		return 7 + 4 * 32;
	}

	override public function renderIcon(screen:Screen, x:Int, y:Int) {
		screen.render(x, y, getSprite(), getColor(), 0);
	}

	override public function renderInventory(screen:Screen, x:Int, y:Int) {
		screen.render(x, y, getSprite(), getColor(), 0);
		Font.draw(getName(), screen, x + 8, y, Color.get(-1, 555, 555, 555));
	}

	override public function getName():String {
		return "Pow glove";
	}

	override public function interact(player:Player, entity:Entity, attackDir:Int):Bool {
		if (Std.isOfType(entity, Furniture)) {
			var f = cast(entity, Furniture);
			f.take(player);
			return true;
		}
		return false;
	}
}
