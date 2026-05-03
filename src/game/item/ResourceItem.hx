package game.item;

import engine.item.Item;

import engine.entity.ItemEntity;
import game.entity.Player;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;
import engine.item.resource.Resource;
import engine.level.Level;
import engine.level.tile.Tile;

class ResourceItem extends Item {
	public var resource:Resource;
	public var count:Int = 1;

	public function new(resource:Resource, count:Int = 1) {
		super();
		this.resource = resource;
		this.count = count;
	}

	override public function getColor():Int {
		return resource.color;
	}

	override public function getSprite():Int {
		return resource.sprite;
	}

	override public function renderIcon(screen:Screen, x:Int, y:Int) {
		screen.render(x, y, resource.sprite, 0);
	}

	override public function renderInventory(screen:Screen, x:Int, y:Int) {
		screen.render(x, y, resource.sprite, 0);
		Font.draw(resource.name, screen, x + 32, y, Color.get(-1, 555, 555, 555));
		var cc = count;
		if (cc > 999) cc = 999;
		Font.draw("" + cc, screen, x + 8, y, Color.get(-1, 444, 444, 444));
	}

	override public function getName():String {
		return resource.name;
	}

	override public function onTake(itemEntity:ItemEntity) {
	}

	override public function interactOn(tile:Tile, level:Level, xt:Int, yt:Int, player:Player, attackDir:Int):Bool {
		if (resource.interactOn(tile, level, xt, yt, player, attackDir)) {
			count--;
			return true;
		}
		return false;
	}

	override public function isDepleted():Bool {
		return count <= 0;
	}
}
