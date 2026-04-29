package com.mojang.ld22.crafting;

import com.mojang.ld22.entity.Anvil;
import com.mojang.ld22.entity.Chest;
import com.mojang.ld22.entity.Furnace;
import com.mojang.ld22.entity.Oven;
import com.mojang.ld22.entity.Lantern;
import com.mojang.ld22.entity.Workbench;
import com.mojang.ld22.item.ToolType;
import com.mojang.ld22.item.resource.Resource;

class Crafting {
	public static var anvilRecipes:Array<Recipe> = [];
	public static var ovenRecipes:Array<Recipe> = [];
	public static var furnaceRecipes:Array<Recipe> = [];
	public static var workbenchRecipes:Array<Recipe> = [];
	static var initialized = false;

	public static function init() {
		if (initialized) return;
		initialized = true;
		workbenchRecipes.push(new FurnitureRecipe(function() return new Lantern()).addCost(Resource.wood, 5).addCost(Resource.slime, 10).addCost(Resource.glass, 4));

		workbenchRecipes.push(new FurnitureRecipe(function() return new Oven()).addCost(Resource.stone, 15));
		workbenchRecipes.push(new FurnitureRecipe(function() return new Furnace()).addCost(Resource.stone, 20));
		workbenchRecipes.push(new FurnitureRecipe(function() return new Workbench()).addCost(Resource.wood, 20));
		workbenchRecipes.push(new FurnitureRecipe(function() return new Chest()).addCost(Resource.wood, 20));
		workbenchRecipes.push(new FurnitureRecipe(function() return new Anvil()).addCost(Resource.ironIngot, 5));

		workbenchRecipes.push(new ToolRecipe(ToolType.sword, 0).addCost(Resource.wood, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.axe, 0).addCost(Resource.wood, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.hoe, 0).addCost(Resource.wood, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.pickaxe, 0).addCost(Resource.wood, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.shovel, 0).addCost(Resource.wood, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.sword, 1).addCost(Resource.wood, 5).addCost(Resource.stone, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.axe, 1).addCost(Resource.wood, 5).addCost(Resource.stone, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.hoe, 1).addCost(Resource.wood, 5).addCost(Resource.stone, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.pickaxe, 1).addCost(Resource.wood, 5).addCost(Resource.stone, 5));
		workbenchRecipes.push(new ToolRecipe(ToolType.shovel, 1).addCost(Resource.wood, 5).addCost(Resource.stone, 5));

		anvilRecipes.push(new ToolRecipe(ToolType.sword, 2).addCost(Resource.wood, 5).addCost(Resource.ironIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.axe, 2).addCost(Resource.wood, 5).addCost(Resource.ironIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.hoe, 2).addCost(Resource.wood, 5).addCost(Resource.ironIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.pickaxe, 2).addCost(Resource.wood, 5).addCost(Resource.ironIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.shovel, 2).addCost(Resource.wood, 5).addCost(Resource.ironIngot, 5));

		anvilRecipes.push(new ToolRecipe(ToolType.sword, 3).addCost(Resource.wood, 5).addCost(Resource.goldIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.axe, 3).addCost(Resource.wood, 5).addCost(Resource.goldIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.hoe, 3).addCost(Resource.wood, 5).addCost(Resource.goldIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.pickaxe, 3).addCost(Resource.wood, 5).addCost(Resource.goldIngot, 5));
		anvilRecipes.push(new ToolRecipe(ToolType.shovel, 3).addCost(Resource.wood, 5).addCost(Resource.goldIngot, 5));

		anvilRecipes.push(new ToolRecipe(ToolType.sword, 4).addCost(Resource.wood, 5).addCost(Resource.gem, 50));
		anvilRecipes.push(new ToolRecipe(ToolType.axe, 4).addCost(Resource.wood, 5).addCost(Resource.gem, 50));
		anvilRecipes.push(new ToolRecipe(ToolType.hoe, 4).addCost(Resource.wood, 5).addCost(Resource.gem, 50));
		anvilRecipes.push(new ToolRecipe(ToolType.pickaxe, 4).addCost(Resource.wood, 5).addCost(Resource.gem, 50));
		anvilRecipes.push(new ToolRecipe(ToolType.shovel, 4).addCost(Resource.wood, 5).addCost(Resource.gem, 50));

		furnaceRecipes.push(new ResourceRecipe(Resource.ironIngot).addCost(Resource.ironOre, 4).addCost(Resource.coal, 1));
		furnaceRecipes.push(new ResourceRecipe(Resource.goldIngot).addCost(Resource.goldOre, 4).addCost(Resource.coal, 1));
		furnaceRecipes.push(new ResourceRecipe(Resource.glass).addCost(Resource.sand, 4).addCost(Resource.coal, 1));

		ovenRecipes.push(new ResourceRecipe(Resource.bread).addCost(Resource.wheat, 4));
	}
}
