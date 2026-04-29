package com.mojang.ld22.item.resource;

import com.mojang.ld22.entity.Player;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.level.Level;
import com.mojang.ld22.level.tile.Tile;

class Resource {
	public static var wood:Resource = new Resource("Wood", 1 + 4 * 32, Color.get(-1, 200, 531, 430));
	public static var stone:Resource = new Resource("Stone", 2 + 4 * 32, Color.get(-1, 111, 333, 555));
	public static var flower:Resource = new PlantableResource("Flower", 0 + 4 * 32, Color.get(-1, 10, 444, 330), Tile.flower, Tile.grass);
	public static var acorn:Resource = new PlantableResource("Acorn", 3 + 4 * 32, Color.get(-1, 100, 531, 320), Tile.treeSapling, Tile.grass);
	public static var dirt:Resource = new PlantableResource("Dirt", 2 + 4 * 32, Color.get(-1, 100, 322, 432), Tile.dirt, Tile.hole, Tile.water, Tile.lava);
	public static var sand:Resource = new PlantableResource("Sand", 2 + 4 * 32, Color.get(-1, 110, 440, 550), Tile.sand, Tile.grass, Tile.dirt);
	public static var cactusFlower:Resource = new PlantableResource("Cactus", 4 + 4 * 32, Color.get(-1, 10, 40, 50), Tile.cactusSapling, Tile.sand);
	public static var seeds:Resource = new PlantableResource("Seeds", 5 + 4 * 32, Color.get(-1, 10, 40, 50), Tile.wheat, Tile.farmland);
	public static var wheat:Resource = new Resource("Wheat", 6 + 4 * 32, Color.get(-1, 110, 330, 550));
	public static var bread:Resource = new FoodResource("Bread", 8 + 4 * 32, Color.get(-1, 110, 330, 550), 2, 5);
	public static var apple:Resource = new FoodResource("Apple", 9 + 4 * 32, Color.get(-1, 100, 300, 500), 1, 5);

	public static var coal:Resource = new Resource("COAL", 10 + 4 * 32, Color.get(-1, 0, 111, 111));
	public static var ironOre:Resource = new Resource("I.ORE", 10 + 4 * 32, Color.get(-1, 100, 322, 544));
	public static var goldOre:Resource = new Resource("G.ORE", 10 + 4 * 32, Color.get(-1, 110, 440, 553));
	public static var ironIngot:Resource = new Resource("IRON", 11 + 4 * 32, Color.get(-1, 100, 322, 544));
	public static var goldIngot:Resource = new Resource("GOLD", 11 + 4 * 32, Color.get(-1, 110, 330, 553));

	public static var slime:Resource = new Resource("SLIME", 10 + 4 * 32, Color.get(-1, 10, 30, 50));
	public static var glass:Resource = new Resource("glass", 12 + 4 * 32, Color.get(-1, 555, 555, 555));
	public static var cloth:Resource = new Resource("cloth", 1 + 4 * 32, Color.get(-1, 25, 252, 141));
	public static var cloud:Resource = new PlantableResource("cloud", 2 + 4 * 32, Color.get(-1, 222, 555, 444), Tile.cloud, Tile.infiniteFall);
	public static var gem:Resource = new Resource("gem", 13 + 4 * 32, Color.get(-1, 101, 404, 545));

	public var name:String;
	public var sprite:Int;
	public var color:Int;

	public function new(name:String, sprite:Int, color:Int) {
		if (name.length > 6) throw "Name cannot be longer than six characters!";
		this.name = name;
		this.sprite = sprite;
		this.color = color;
	}

	public function interactOn(tile:Tile, level:Level, xt:Int, yt:Int, player:Player, attackDir:Int):Bool {
		return false;
	}
}
