package com.mojang.ld22.crafting;

import com.mojang.ld22.entity.Player;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Font;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.item.Item;
import com.mojang.ld22.item.ResourceItem;
import com.mojang.ld22.item.resource.Resource;
import com.mojang.ld22.screen.ListItem;

class Recipe implements ListItem {
	public var costs:Array<Item> = [];
	public var canCraft:Bool = false;
	public var resultTemplate:Item;

	public function new(resultTemplate:Item) {
		this.resultTemplate = resultTemplate;
	}

	public function addCost(resource:Resource, count:Int):Recipe {
		costs.push(new ResourceItem(resource, count));
		return this;
	}

	public function checkCanCraft(player:Player):Void {
		for (i in 0...costs.length) {
			var item = costs[i];
			if (Std.isOfType(item, ResourceItem)) {
				var ri = cast(item, ResourceItem);
				if (!player.inventory.hasResources(ri.resource, ri.count)) {
					canCraft = false;
					return;
				}
			}
		}
		canCraft = true;
	}

	public function renderInventory(screen:Screen, x:Int, y:Int):Void {
		screen.render(x, y, resultTemplate.getSprite(), resultTemplate.getColor(), 0);
		var textColor = canCraft ? Color.get(-1, 555, 555, 555) : Color.get(-1, 222, 222, 222);
		Font.draw(resultTemplate.getName(), screen, x + 8, y, textColor);
	}

	public function craft(player:Player):Void {
		throw "abstract";
	}

	public function deductCost(player:Player):Void {
		for (i in 0...costs.length) {
			var item = costs[i];
			if (Std.isOfType(item, ResourceItem)) {
				var ri = cast(item, ResourceItem);
				player.inventory.removeResource(ri.resource, ri.count);
			}
		}
	}
}
