package game.item;

import engine.item.Item;
import engine.item.ToolType;

import engine.entity.Entity;
import engine.entity.ItemEntity;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;
import engine.gfx.SpriteId;
import game.SpriteNames;

class ToolItem extends Item {
	var random = new engine.utils.Random();

	public static var MAX_LEVEL:Int = 5;
	public static var LEVEL_NAMES:Array<String> = [
		"Wood", "Rock", "Iron", "Gold", "Gem"
	];

	public static var LEVEL_COLORS:Array<Int> = [
		Color.get(-1, 100, 321, 431),
		Color.get(-1, 100, 321, 111),
		Color.get(-1, 100, 321, 555),
		Color.get(-1, 100, 321, 550),
		Color.get(-1, 100, 321, 45),
	];

	public var type:ToolType;
	public var level:Int = 0;

	public function new(type:ToolType, level:Int) {
		super();
		this.type = type;
		this.level = level;
	}

	override public function getColor():Int {
		return LEVEL_COLORS[level];
	}

	override public function getSprite():SpriteId {
		return SpriteNames.itemRawTile(type.sprite + 5 * 32);
	}

	override public function renderIcon(screen:Screen, x:Int, y:Int) {
		screen.renderSprite(x, y, getSprite(), getColor(), 0);
	}

	override public function renderInventory(screen:Screen, x:Int, y:Int) {
		screen.renderSprite(x, y, getSprite(), getColor(), 0);
		Font.draw(getName(), screen, x + 8, y, Color.get(-1, 555, 555, 555));
	}

	override public function getName():String {
		return LEVEL_NAMES[level] + " " + type.name;
	}

	override public function onTake(itemEntity:ItemEntity) {
	}

	override public function canAttack():Bool {
		return true;
	}

	override public function getAttackDamageBonus(e:Entity):Int {
		if (type == ToolType.axe) {
			return (level + 1) * 2 + random.nextInt(4);
		}
		if (type == ToolType.sword) {
			return (level + 1) * 3 + random.nextInt(2 + level * level * 2);
		}
		return 1;
	}

	override public function matches(item:Item):Bool {
		if (Std.isOfType(item, ToolItem)) {
			var other = cast(item, ToolItem);
			if (other.type != type) return false;
			if (other.level != level) return false;
			return true;
		}
		return false;
	}
}
