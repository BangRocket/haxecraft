package entity;

import gfx.Screen;
import item.FurnitureItem;
import item.PowerGloveItem;

class Furniture extends Entity {
	var pushTime:Int = 0;
	var pushDir:Int = -1;
	public var col:Int;
	public var sprite:Int;
	public var name:String;
	var shouldTake:Player;

	public function new(name:String) {
		super();
		this.name = name;
		xr = 3;
		yr = 3;
	}

	override public function tick() {
		if (shouldTake != null) {
			if (Std.isOfType(shouldTake.activeItem, PowerGloveItem)) {
				remove();
				shouldTake.inventory.addSlot(0, shouldTake.activeItem);
				shouldTake.activeItem = new FurnitureItem(this);
			}
			shouldTake = null;
		}
		if (pushDir == 0) move(0, 1);
		if (pushDir == 1) move(0, -1);
		if (pushDir == 2) move(-1, 0);
		if (pushDir == 3) move(1, 0);
		pushDir = -1;
		if (pushTime > 0) pushTime--;
	}

	override public function render(screen:Screen) {
		screen.render(x - 8, y - 8 - 4, sprite * 2 + 8 * 32, 0);
		screen.render(x - 0, y - 8 - 4, sprite * 2 + 8 * 32 + 1, 0);
		screen.render(x - 8, y - 0 - 4, sprite * 2 + 8 * 32 + 32, 0);
		screen.render(x - 0, y - 0 - 4, sprite * 2 + 8 * 32 + 33, 0);
	}

	override public function blocks(e:Entity):Bool {
		return true;
	}

	override function touchedBy(entity:Entity) {
		if (Std.isOfType(entity, Player) && pushTime == 0) {
			pushDir = cast(entity, Player).dir;
			pushTime = 10;
		}
	}

	public function take(player:Player) {
		shouldTake = player;
	}
}
