package game.item;

import engine.item.Item;

import game.entity.Furniture;
import engine.entity.ItemEntity;
import game.entity.Player;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;
import engine.level.Level;
import engine.level.tile.Tile;

class FurnitureItem extends Item {
	public var furniture:Furniture;
	public var placed:Bool = false;

	public function new(furniture:Furniture) {
		super();
		this.furniture = furniture;
	}

	override public function getColor():Int {
		return furniture.col;
	}

	override public function getSprite():Int {
		return furniture.sprite + 10 * 32;
	}

	override public function renderIcon(screen:Screen, x:Int, y:Int) {
		screen.render(x, y, getSprite(), getColor(), 0);
	}

	override public function renderInventory(screen:Screen, x:Int, y:Int) {
		screen.render(x, y, getSprite(), getColor(), 0);
		Font.draw(furniture.name, screen, x + 8, y, Color.get(-1, 555, 555, 555));
	}

	override public function onTake(itemEntity:ItemEntity) {
	}

	override public function canAttack():Bool {
		return false;
	}

	override public function interactOn(tile:Tile, level:Level, xt:Int, yt:Int, player:Player, attackDir:Int):Bool {
		if (tile.mayPass(level, xt, yt, furniture)) {
			furniture.x = xt * 16 + 8;
			furniture.y = yt * 16 + 8;
			level.add(furniture);
			placed = true;
			return true;
		}
		return false;
	}

	override public function isDepleted():Bool {
		return placed;
	}

	override public function getName():String {
		return furniture.name;
	}
}
