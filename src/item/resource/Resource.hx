package item.resource;

import entity.Player;
import gfx.Color;
import level.Level;
import level.tile.Tile;

class Resource {
	public static var wood:Resource;
	public static var stone:Resource;
	public static var flower:Resource;
	public static var acorn:Resource;
	public static var dirt:Resource;
	public static var sand:Resource;
	public static var cactusFlower:Resource;
	public static var seeds:Resource;
	public static var wheat:Resource;
	public static var bread:Resource;
	public static var apple:Resource;

	public static var coal:Resource;
	public static var ironOre:Resource;
	public static var goldOre:Resource;
	public static var ironIngot:Resource;
	public static var goldIngot:Resource;

	public static var slime:Resource;
	public static var glass:Resource;
	public static var cloth:Resource;
	public static var cloud:Resource;
	public static var gem:Resource;

	static var initialized:Bool = false;
	public static function init():Void {
		if (initialized) return;
		initialized = true;
		wood        = new Resource("Wood", 1 + 4 * 32, Color.get(-1, 200, 531, 430));
		stone       = new Resource("Stone", 2 + 4 * 32, Color.get(-1, 111, 333, 555));
		flower      = new PlantableResource("Flower", 0 + 4 * 32, Color.get(-1, 10, 444, 330), Tile.flower, Tile.grass);
		acorn       = new PlantableResource("Acorn", 3 + 4 * 32, Color.get(-1, 100, 531, 320), Tile.treeSapling, Tile.grass);
		dirt        = new PlantableResource("Dirt", 2 + 4 * 32, Color.get(-1, 100, 322, 432), Tile.dirt, Tile.hole, Tile.water, Tile.lava);
		sand        = new PlantableResource("Sand", 2 + 4 * 32, Color.get(-1, 110, 440, 550), Tile.sand, Tile.grass, Tile.dirt);
		cactusFlower = new PlantableResource("Cactus", 4 + 4 * 32, Color.get(-1, 10, 40, 50), Tile.cactusSapling, Tile.sand);
		seeds       = new PlantableResource("Seeds", 5 + 4 * 32, Color.get(-1, 10, 40, 50), Tile.wheat, Tile.farmland);
		wheat       = new Resource("Wheat", 6 + 4 * 32, Color.get(-1, 110, 330, 550));
		bread       = new FoodResource("Bread", 8 + 4 * 32, Color.get(-1, 110, 330, 550), 2, 5);
		apple       = new FoodResource("Apple", 9 + 4 * 32, Color.get(-1, 100, 300, 500), 1, 5);
		coal        = new Resource("COAL", 10 + 4 * 32, Color.get(-1, 0, 111, 111));
		ironOre     = new Resource("I.ORE", 10 + 4 * 32, Color.get(-1, 100, 322, 544));
		goldOre     = new Resource("G.ORE", 10 + 4 * 32, Color.get(-1, 110, 440, 553));
		ironIngot   = new Resource("IRON", 11 + 4 * 32, Color.get(-1, 100, 322, 544));
		goldIngot   = new Resource("GOLD", 11 + 4 * 32, Color.get(-1, 110, 330, 553));
		slime       = new Resource("SLIME", 10 + 4 * 32, Color.get(-1, 10, 30, 50));
		glass       = new Resource("glass", 12 + 4 * 32, Color.get(-1, 555, 555, 555));
		cloth       = new Resource("cloth", 1 + 4 * 32, Color.get(-1, 25, 252, 141));
		cloud       = new PlantableResource("cloud", 2 + 4 * 32, Color.get(-1, 222, 555, 444), Tile.cloud, Tile.infiniteFall);
		gem         = new Resource("gem", 13 + 4 * 32, Color.get(-1, 101, 404, 545));
	}

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
