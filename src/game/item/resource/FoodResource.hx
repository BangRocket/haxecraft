package game.item.resource;

import engine.item.resource.Resource;

import game.entity.Player;
import engine.level.Level;
import engine.level.tile.Tile;

class FoodResource extends Resource {
	var heal:Int;
	var staminaCost:Int;

	public function new(name:String, sprite:Int, color:Int, heal:Int, staminaCost:Int) {
		super(name, sprite, color);
		this.heal = heal;
		this.staminaCost = staminaCost;
	}

	override public function interactOn(tile:Tile, level:Level, xt:Int, yt:Int, player:Player, attackDir:Int):Bool {
		if (player.health < player.maxHealth && player.payStamina(staminaCost)) {
			player.heal(heal);
			return true;
		}
		return false;
	}
}
