package com.mojang.ld22.item;

import com.mojang.ld22.entity.Entity;
import com.mojang.ld22.entity.ItemEntity;
import com.mojang.ld22.entity.Player;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.level.Level;
import com.mojang.ld22.level.tile.Tile;
import com.mojang.ld22.screen.ListItem;

class Item implements ListItem {
	public function new() {}

	public function getColor():Int {
		return 0;
	}

	public function getSprite():Int {
		return 0;
	}

	public function onTake(itemEntity:ItemEntity) {}

	public function renderInventory(screen:Screen, x:Int, y:Int) {}

	public function interact(player:Player, entity:Entity, attackDir:Int):Bool {
		return false;
	}

	public function renderIcon(screen:Screen, x:Int, y:Int) {}

	public function interactOn(tile:Tile, level:Level, xt:Int, yt:Int, player:Player, attackDir:Int):Bool {
		return false;
	}

	public function isDepleted():Bool {
		return false;
	}

	public function canAttack():Bool {
		return false;
	}

	public function getAttackDamageBonus(e:Entity):Int {
		return 0;
	}

	public function getName():String {
		return "";
	}

	public function matches(item:Item):Bool {
		return Type.getClass(item) == Type.getClass(this);
	}
}
