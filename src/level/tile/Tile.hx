package level.tile;

import entity.Entity;
import entity.Mob;
import entity.Player;
import gfx.Screen;
import item.Item;
import level.Level;
import utils.Random;

class Tile {
	public static var tickCount:Int = 0;
	public var random:Random = new Random();

	public static var tiles:Array<Tile> = [for (i in 0...256) null];
	public static var grass:Tile = new GrassTile(0);
	public static var rock:Tile = new RockTile(1);
	public static var water:Tile = new WaterTile(2);
	public static var flower:Tile = new FlowerTile(3);
	public static var tree:Tile = new TreeTile(4);
	public static var dirt:Tile = new DirtTile(5);
	public static var sand:Tile = new SandTile(6);
	public static var cactus:Tile = new CactusTile(7);
	public static var hole:Tile = new HoleTile(8);
	public static var treeSapling:Tile = new SaplingTile(9, grass, tree);
	public static var cactusSapling:Tile = new SaplingTile(10, sand, cactus);
	public static var farmland:Tile = new FarmTile(11);
	public static var wheat:Tile = new WheatTile(12);
	public static var lava:Tile = new LavaTile(13);
	public static var stairsDown:Tile = new StairsTile(14, false);
	public static var stairsUp:Tile = new StairsTile(15, true);
	public static var infiniteFall:Tile = new InfiniteFallTile(16);
	public static var cloud:Tile = new CloudTile(17);
	public static var hardRock:Tile = new HardRockTile(18);
	public static var ironOre:Tile = new OreTile(19, function() return item.resource.Resource.ironOre);
	public static var goldOre:Tile = new OreTile(20, function() return item.resource.Resource.goldOre);
	public static var gemOre:Tile = new OreTile(21, function() return item.resource.Resource.gem);
	public static var cloudCactus:Tile = new CloudCactusTile(22);

	public var id:Int;

	public var connectsToGrass:Bool = false;
	public var connectsToSand:Bool = false;
	public var connectsToLava:Bool = false;
	public var connectsToWater:Bool = false;
	public var isTall:Bool = false;

	public function new(id:Int) {
		this.id = id & 0xff;
		if (tiles[id] != null) throw "Duplicate tile ids!";
		tiles[id] = this;
	}

	public function render(screen:Screen, level:Level, x:Int, y:Int) {}

	public function mayPass(level:Level, x:Int, y:Int, e:Entity):Bool {
		return true;
	}

	public function getLightRadius(level:Level, x:Int, y:Int):Int {
		return 0;
	}

	public function hurt(level:Level, x:Int, y:Int, source:Mob, dmg:Int, attackDir:Int) {}

	public function bumpedInto(level:Level, xt:Int, yt:Int, entity:Entity) {}

	public function tick(level:Level, xt:Int, yt:Int) {}

	public function steppedOn(level:Level, xt:Int, yt:Int, entity:Entity) {}

	public function interact(level:Level, xt:Int, yt:Int, player:Player, item:Item, attackDir:Int):Bool {
		return false;
	}

	public function use(level:Level, xt:Int, yt:Int, player:Player, attackDir:Int):Bool {
		return false;
	}

	public function connectsToLiquid():Bool {
		return connectsToWater || connectsToLava;
	}
}
