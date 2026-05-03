package game.screen;

import engine.screen.Menu;

import game.entity.Player;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;
import engine.item.Item;
import game.item.ResourceItem;

class InventoryMenu extends Menu {
	var player:Player;
	var selected = 0;
	var window = 0; // 0 = inventory, 1 = hotbar

	public function new(player:Player) {
		super();
		this.player = player;

		if (player.activeItem != null) {
			player.inventory.items.insert(0, player.activeItem);
			player.activeItem = null;
		}
	}

	override public function tick() {
		if (input.menu.clicked) game.setMenu(null);

		if (input.left.clicked) window = 0;
		if (input.right.clicked) window = 1;

		if (input.up.clicked) selected--;
		if (input.down.clicked) selected++;

		var len = window == 0 ? player.inventory.items.length : 8;
		if (len == 0) selected = 0;
		if (selected < 0) selected += len;
		if (selected >= len) selected -= len;

		if (input.attack.clicked && len > 0) {
			if (window == 0) {
				// Move from inventory to hotbar
				var item = player.inventory.items[selected];
				player.inventory.items.splice(selected, 1);
				// Find first empty hotbar slot
				var placed = false;
				for (i in 0...8) {
					if (player.hotbar[i] == null) {
						player.hotbar[i] = item;
						placed = true;
						break;
					}
				}
				if (!placed) {
					// Hotbar full, put back in inventory
					player.inventory.add(item);
				}
			} else {
				// Move from hotbar to inventory
				var item = player.hotbar[selected];
				if (item != null) {
					player.hotbar[selected] = null;
					player.inventory.add(item);
				}
			}
		}
	}

	override public function render(screen:Screen) {
		Font.renderFrame(screen, "inventory", 1, 1, 12, 11);
		renderItemList(screen, 1, 1, 12, 11, cast player.inventory.items, window == 0 ? selected : -1);

		// Hotbar pane
		Font.renderFrame(screen, "hotbar", 13, 1, 20, 11);
		for (i in 0...8) {
			var item = player.hotbar[i];
			var yo = (i + 1) * 8;
			Font.draw("" + (i + 1), screen, 14 * 8, yo, Color.get(-1, 333, 333, 333));
			if (item != null) {
				item.renderIcon(screen, 16 * 8, yo);
				if (Std.isOfType(item, ResourceItem)) {
					var ri = cast(item, ResourceItem);
					if (ri.count > 1) {
						Font.draw("" + ri.count, screen, 17 * 8, yo, Color.get(-1, 555, 555, 555));
					}
				}
			}
		}
		if (window == 1) {
			Font.draw(">", screen, 13 * 8, (selected + 1) * 8, Color.get(5, 555, 555, 555));
			Font.draw("<", screen, 20 * 8, (selected + 1) * 8, Color.get(5, 555, 555, 555));
		}
	}
}
