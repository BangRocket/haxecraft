package item;

import entity.Furniture;
import entity.ItemEntity;
import entity.Player;
import gfx.Color;
import gfx.Font;
import gfx.Screen;
import level.Level;
import level.tile.Tile;

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
		screen.render(x, y, getSprite(), 0, screen.colorSheet);
	}

	override public function renderInventory(screen:Screen, x:Int, y:Int) {
		screen.render(x, y, getSprite(), 0, screen.colorSheet);
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
