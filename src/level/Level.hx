package level;

import entity.AirWizard;
import entity.Entity;
import entity.Mob;
import entity.Player;
import entity.Slime;
import entity.Zombie;
import gfx.Screen;
import level.levelgen.LevelGen;
import level.tile.Tile;
import utils.Random;

class Level {
	var random = new Random();

	public var w:Int;
	public var h:Int;

	public var tiles:Array<Int>;
	public var data:Array<Int>;
	public var groundTiles:Array<Int>;
	public var entitiesInTiles:Array<Array<Entity>>;

	public var grassColor:Int = 141;
	public var dirtColor:Int = 322;
	public var sandColor:Int = 550;
	var depth:Int;
	public var monsterDensity:Int = 8;

	public var entities:Array<Entity> = [];

	public var player:Player;

	public function new(w:Int, h:Int, level:Int, parentLevel:Level) {
		if (level < 0) {
			dirtColor = 222;
		}
		this.depth = level;
		this.w = w;
		this.h = h;
		var maps:Array<Array<Int>>;

		if (level == 1) {
			dirtColor = 444;
		}
		if (level == 0)
			maps = LevelGen.createAndValidateTopMap(w, h);
		else if (level < 0) {
			maps = LevelGen.createAndValidateUndergroundMap(w, h, -level);
			monsterDensity = 4;
		} else {
			maps = LevelGen.createAndValidateSkyMap(w, h);
			monsterDensity = 4;
		}

		tiles = maps[0];
		data = maps[1];
		groundTiles = maps[2];

		if (parentLevel != null) {
			for (y in 0...h) {
				for (x in 0...w) {
					if (parentLevel.getTile(x, y) == Tile.stairsDown) {
						setTile(x, y, Tile.stairsUp, 0);
						if (level == 0) {
							setTile(x - 1, y, Tile.hardRock, 0);
							setTile(x + 1, y, Tile.hardRock, 0);
							setTile(x, y - 1, Tile.hardRock, 0);
							setTile(x, y + 1, Tile.hardRock, 0);
							setTile(x - 1, y - 1, Tile.hardRock, 0);
							setTile(x - 1, y + 1, Tile.hardRock, 0);
							setTile(x + 1, y - 1, Tile.hardRock, 0);
							setTile(x + 1, y + 1, Tile.hardRock, 0);
						} else {
							setTile(x - 1, y, Tile.dirt, 0);
							setTile(x + 1, y, Tile.dirt, 0);
							setTile(x, y - 1, Tile.dirt, 0);
							setTile(x, y + 1, Tile.dirt, 0);
							setTile(x - 1, y - 1, Tile.dirt, 0);
							setTile(x - 1, y + 1, Tile.dirt, 0);
							setTile(x + 1, y - 1, Tile.dirt, 0);
							setTile(x + 1, y + 1, Tile.dirt, 0);
						}
					}
				}
			}
		}

		entitiesInTiles = [];
		for (i in 0...w * h) {
			entitiesInTiles.push([]);
		}

		if (level == 1) {
			var aw = new AirWizard();
			aw.x = w * 8;
			aw.y = h * 8;
			add(aw);
		}
	}

	public function renderBackground(screen:Screen, xScroll:Int, yScroll:Int) {
		var xo = xScroll >> 4;
		var yo = yScroll >> 4;
		var w = (screen.w + 15) >> 4;
		var h = (screen.h + 15) >> 4;
		screen.setOffset(xScroll, yScroll);
		for (y in yo...(h + yo + 1)) {
			for (x in xo...(w + xo + 1)) {
				getGroundTile(x, y).render(screen, this, x, y);
			}
		}
		screen.setOffset(0, 0);
	}

	var rowSprites:Array<Entity> = [];

	public function renderSprites(screen:Screen, xScroll:Int, yScroll:Int) {
		var xo = xScroll >> 4;
		var yo = yScroll >> 4;
		var w = (screen.w + 15) >> 4;
		var h = (screen.h + 15) >> 4;

		screen.setOffset(xScroll, yScroll);
		for (y in yo...(h + yo + 1)) {
			for (x in xo...(w + xo + 1)) {
				if (x < 0 || y < 0 || x >= this.w || y >= this.h) continue;
				var tile = getTile(x, y);
				if (tile.isTall) {
					tile.render(screen, this, x, y);
				}
			}
			for (x in xo...(w + xo + 1)) {
				if (x < 0 || y < 0 || x >= this.w || y >= this.h) continue;
				for (e in entitiesInTiles[x + y * this.w]) {
					rowSprites.push(e);
				}
			}
			if (rowSprites.length > 0) {
				sortAndRender(screen, rowSprites);
			}
			rowSprites.resize(0);
		}
		screen.setOffset(0, 0);
	}

	public function renderLight(screen:Screen, xScroll:Int, yScroll:Int) {
		var xo = xScroll >> 4;
		var yo = yScroll >> 4;
		var w = (screen.w + 15) >> 4;
		var h = (screen.h + 15) >> 4;

		screen.setOffset(xScroll, yScroll);
		var r = 4;
		for (y in (yo - r)...((h + yo + r) + 1)) {
			for (x in (xo - r)...((w + xo + r) + 1)) {
				if (x < 0 || y < 0 || x >= this.w || y >= this.h) continue;
				var entities = entitiesInTiles[x + y * this.w];
				for (i in 0...entities.length) {
					var e = entities[i];
					var lr = e.getLightRadius();
					if (lr > 0) screen.renderLight(e.x - 1, e.y - 4, lr * 8);
				}
				var lr = getTile(x, y).getLightRadius(this, x, y);
				if (lr > 0) screen.renderLight(x * 16 + 8, y * 16 + 8, lr * 8);
			}
		}
		screen.setOffset(0, 0);
	}

	function sortAndRender(screen:Screen, list:Array<Entity>) {
		list.sort(function(e0, e1) {
			if (e1.y < e0.y) return 1;
			if (e1.y > e0.y) return -1;
			return 0;
		});
		for (i in 0...list.length) {
			list[i].render(screen);
		}
	}

	public inline function getTile(x:Int, y:Int):Tile {
		if (x < 0 || y < 0 || x >= w || y >= h) return Tile.rock;
		return Tile.tiles[tiles[x + y * w]];
	}

	public function getGroundTile(x:Int, y:Int):Tile {
		if (x < 0 || y < 0 || x >= w || y >= h) return Tile.rock;
		return Tile.tiles[groundTiles[x + y * w]];
	}

	public function setTile(x:Int, y:Int, t:Tile, dataVal:Int) {
		if (x < 0 || y < 0 || x >= w || y >= h) return;
		var idx = x + y * w;
		if (!t.isTall) {
			groundTiles[idx] = t.id;
		}
		tiles[idx] = t.id;
		data[idx] = dataVal;
	}

	public inline function getData(x:Int, y:Int):Int {
		if (x < 0 || y < 0 || x >= w || y >= h) return 0;
		return data[x + y * w] & 0xff;
	}

	public inline function setData(x:Int, y:Int, val:Int) {
		if (x < 0 || y < 0 || x >= w || y >= h) return;
		data[x + y * w] = val;
	}

	public function add(entity:Entity) {
		if (Std.isOfType(entity, Player)) {
			player = cast entity;
		}
		entity.removed = false;
		entities.push(entity);
		entity.init(this);
		insertEntity(entity.x >> 4, entity.y >> 4, entity);
	}

	public function remove(e:Entity) {
		entities.remove(e);
		var xto = e.x >> 4;
		var yto = e.y >> 4;
		removeEntity(xto, yto, e);
	}

	function insertEntity(x:Int, y:Int, e:Entity) {
		if (x < 0 || y < 0 || x >= w || y >= h) return;
		entitiesInTiles[x + y * w].push(e);
	}

	function removeEntity(x:Int, y:Int, e:Entity) {
		if (x < 0 || y < 0 || x >= w || y >= h) return;
		entitiesInTiles[x + y * w].remove(e);
	}

	public function trySpawn(count:Int) {
		for (i in 0...count) {
			var mob:Mob;

			var minLevel = 1;
			var maxLevel = 1;
			if (depth < 0) {
				maxLevel = (-depth) + 1;
			}
			if (depth > 0) {
				minLevel = maxLevel = 4;
			}

			var lvl = random.nextInt(maxLevel - minLevel + 1) + minLevel;
			if (random.nextInt(2) == 0)
				mob = new Slime(lvl);
			else
				mob = new Zombie(lvl);

			if (mob.findStartPos(this)) {
				this.add(mob);
			}
		}
	}

	var randomTickCount:Int = 0;

	public function tick() {
		trySpawn(1);

		if (randomTickCount == 0) randomTickCount = Std.int(w * h / 50);
		for (i in 0...randomTickCount) {
			var xt = random.nextInt(w);
			var yt = random.nextInt(h);
			getTile(xt, yt).tick(this, xt, yt);
		}
		var i = 0;
		while (i < entities.length) {
			var e = entities[i];
			var xto = e.x >> 4;
			var yto = e.y >> 4;

			e.tick();

			if (e.removed) {
				// Swap-and-pop: O(1) instead of O(n) splice
				var last = entities[entities.length - 1];
				entities[i] = last;
				entities.pop();
				removeEntity(xto, yto, e);
				// don't increment i — re-check swapped element
			} else {
				var xt = e.x >> 4;
				var yt = e.y >> 4;

				if (xto != xt || yto != yt) {
					removeEntity(xto, yto, e);
					insertEntity(xt, yt, e);
				}
				i++;
			}
		}
	}

	public function getEntities(x0:Int, y0:Int, x1:Int, y1:Int):Array<Entity> {
		var result:Array<Entity> = [];
		getEntitiesInto(result, x0, y0, x1, y1);
		return result;
	}

	public function getEntitiesInto(out:Array<Entity>, x0:Int, y0:Int, x1:Int, y1:Int):Void {
		out.resize(0);
		var xt0 = (x0 >> 4) - 1;
		var yt0 = (y0 >> 4) - 1;
		var xt1 = (x1 >> 4) + 1;
		var yt1 = (y1 >> 4) + 1;
		for (y in yt0...(yt1 + 1)) {
			for (x in xt0...(xt1 + 1)) {
				if (x < 0 || y < 0 || x >= w || y >= h) continue;
				var ents = entitiesInTiles[x + y * this.w];
				for (i in 0...ents.length) {
					var e = ents[i];
					if (e.intersects(x0, y0, x1, y1)) out.push(e);
				}
			}
		}
	}
}
