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
	public static var grass:Tile;
	public static var rock:Tile;
	public static var water:Tile;
	public static var flower:Tile;
	public static var tree:Tile;
	public static var dirt:Tile;
	public static var sand:Tile;
	public static var cactus:Tile;
	public static var hole:Tile;
	public static var treeSapling:Tile;
	public static var cactusSapling:Tile;
	public static var farmland:Tile;
	public static var wheat:Tile;
	public static var lava:Tile;
	public static var stairsDown:Tile;
	public static var stairsUp:Tile;
	public static var infiniteFall:Tile;
	public static var cloud:Tile;
	public static var hardRock:Tile;
	public static var ironOre:Tile;
	public static var goldOre:Tile;
	public static var gemOre:Tile;
	public static var cloudCactus:Tile;

	static var initialized:Bool = false;
	public static function init():Void {
		if (initialized) return;
		initialized = true;
		grass         = new GrassTile(0);
		rock          = new RockTile(1);
		water         = new WaterTile(2);
		flower        = new FlowerTile(3);
		tree          = new TreeTile(4);
		dirt          = new DirtTile(5);
		sand          = new SandTile(6);
		cactus        = new CactusTile(7);
		hole          = new HoleTile(8);
		treeSapling   = new SaplingTile(9, grass, tree);
		cactusSapling = new SaplingTile(10, sand, cactus);
		farmland      = new FarmTile(11);
		wheat         = new WheatTile(12);
		lava          = new LavaTile(13);
		stairsDown    = new StairsTile(14, false);
		stairsUp      = new StairsTile(15, true);
		infiniteFall  = new InfiniteFallTile(16);
		cloud         = new CloudTile(17);
		hardRock      = new HardRockTile(18);
		ironOre       = new OreTile(19, function() return item.resource.Resource.ironOre);
		goldOre       = new OreTile(20, function() return item.resource.Resource.goldOre);
		gemOre        = new OreTile(21, function() return item.resource.Resource.gem);
		cloudCactus   = new CloudCactusTile(22);
	}

	public var id:Int;

	public var connectsToGrass:Bool = false;
	public var connectsToSand:Bool = false;
	public var connectsToLava:Bool = false;
	public var connectsToWater:Bool = false;

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
