package game.screen;


import game.crafting.Recipe;
import game.entity.Player;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;
import engine.item.Item;
import game.item.ResourceItem;
import engine.sound.Sound;

class CraftingMenu extends GameMenu {
	var player:Player;
	var selected = 0;

	var recipes:Array<Recipe>;

	public function new(recipes:Array<Recipe>, player:Player) {
		super();
		this.recipes = recipes.copy();
		this.player = player;

		for (i in 0...recipes.length) {
			this.recipes[i].checkCanCraft(player);
		}

		this.recipes.sort(function(r1:Recipe, r2:Recipe) {
			if (r1.canCraft && !r2.canCraft) return -1;
			if (!r1.canCraft && r2.canCraft) return 1;
			return 0;
		});
	}

	override public function tick() {
		if (input.menu.clicked) game.setMenu(null);

		if (input.up.clicked) selected--;
		if (input.down.clicked) selected++;

		var len = recipes.length;
		if (len == 0) selected = 0;
		if (selected < 0) selected += len;
		if (selected >= len) selected -= len;

		if (input.attack.clicked && len > 0) {
			var r = recipes[selected];
			r.checkCanCraft(player);
			if (r.canCraft) {
				r.deductCost(player);
				r.craft(player);
				Sound.craft.play();
			}
			for (i in 0...recipes.length) {
				recipes[i].checkCanCraft(player);
			}
		}
	}

	override public function render(screen:Screen) {
		Font.renderFrame(screen, "Have", 12, 1, 19, 3);
		Font.renderFrame(screen, "Cost", 12, 4, 19, 11);
		Font.renderFrame(screen, "Crafting", 0, 1, 11, 11);
		renderItemList(screen, 0, 1, 11, 11, cast recipes, selected);

		if (recipes.length > 0) {
			var recipe = recipes[selected];
			var hasResultItems = player.inventory.count(recipe.resultTemplate);
			var xo = 13 * 8;
			screen.render(xo, 2 * 8, recipe.resultTemplate.getSprite(), 0);
			Font.draw("" + hasResultItems, screen, xo + 8, 2 * 8, Color.get(-1, 555, 555, 555));

			var costs = recipe.costs;
			for (i in 0...costs.length) {
				var item = costs[i];
				var yo = (5 + i) * 8;
				screen.render(xo, yo, item.getSprite(), 0);
				var requiredAmt = 1;
				if (Std.isOfType(item, ResourceItem)) {
					requiredAmt = cast(item, ResourceItem).count;
				}
				var has = player.inventory.count(item);
				var color = Color.get(-1, 555, 555, 555);
				if (has < requiredAmt) {
					color = Color.get(-1, 222, 222, 222);
				}
				if (has > 99) has = 99;
				Font.draw("" + requiredAmt + "/" + has, screen, xo + 8, yo, color);
			}
		}
		// renderItemList(screen, 12, 4, 19, 11, recipes.get(selected).costs, -1);
	}
}
