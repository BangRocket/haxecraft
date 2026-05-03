package entity;

import gfx.Screen;
import item.Item;
import level.Level;
import level.tile.Tile;

class Entity {
	static var move2WasInside:Array<Entity> = [];
	static var move2IsInside:Array<Entity> = [];

	public var random = new utils.Random();
	public var x:Int;
	public var y:Int;
	public var xr:Int = 6;
	public var yr:Int = 6;
	public var removed:Bool;
	public var level:Level;

	public function new() {}

	public function render(screen:Screen) {}

	public function tick() {}

	public function remove() {
		removed = true;
	}

	public function onRemovedFromLevel() {}

	public final function init(level:Level) {
		this.level = level;
	}

	public inline function intersects(x0:Int, y0:Int, x1:Int, y1:Int):Bool {
		return !(x + xr < x0 || y + yr < y0 || x - xr > x1 || y - yr > y1);
	}

	public function blocks(e:Entity):Bool {
		return false;
	}

	public function hurt(mob:Mob, dmg:Int, attackDir:Int) {}

	public function hurtTile(tile:Tile, x:Int, y:Int, dmg:Int) {}

	public function move(xa:Int, ya:Int):Bool {
		if (xa != 0 || ya != 0) {
			var stopped = true;
			if (xa != 0 && move2(xa, 0)) stopped = false;
			if (ya != 0 && move2(0, ya)) stopped = false;
			if (!stopped) {
				var xt = x >> 4;
				var yt = y >> 4;
				level.getTile(xt, yt).steppedOn(level, xt, yt, this);
			}
			return !stopped;
		}
		return true;
	}

	function move2(xa:Int, ya:Int):Bool {
		if (xa != 0 && ya != 0) throw "Move2 can only move along one axis at a time!";

		var xto0 = ((x) - xr) >> 4;
		var yto0 = ((y) - yr) >> 4;
		var xto1 = ((x) + xr) >> 4;
		var yto1 = ((y) + yr) >> 4;

		var xt0 = ((x + xa) - xr) >> 4;
		var yt0 = ((y + ya) - yr) >> 4;
		var xt1 = ((x + xa) + xr) >> 4;
		var yt1 = ((y + ya) + yr) >> 4;
		var blocked = false;
		for (yt in yt0...(yt1 + 1)) {
			for (xt in xt0...(xt1 + 1)) {
				if (xt >= xto0 && xt <= xto1 && yt >= yto0 && yt <= yto1) continue;
				level.getTile(xt, yt).bumpedInto(level, xt, yt, this);
				if (!level.getTile(xt, yt).mayPass(level, xt, yt, this)) {
					blocked = true;
					return false;
				}
			}
		}
		if (blocked) return false;

		var wasInside = move2WasInside;
		var isInside = move2IsInside;
		level.getEntitiesInto(wasInside, x - xr, y - yr, x + xr, y + yr);
		level.getEntitiesInto(isInside, x + xa - xr, y + ya - yr, x + xa + xr, y + ya + yr);
		for (i in 0...isInside.length) {
			var e = isInside[i];
			if (e == this) continue;
			e.touchedBy(this);
		}
		for (e in wasInside) {
			isInside.remove(e);
		}
		for (i in 0...isInside.length) {
			var e = isInside[i];
			if (e == this) continue;
			if (e.blocks(this)) {
				return false;
			}
		}

		x += xa;
		y += ya;
		return true;
	}

	function touchedBy(entity:Entity) {}

	public function isBlockableBy(mob:Mob):Bool {
		return true;
	}

	public function touchItem(itemEntity:ItemEntity) {}

	public function canSwim():Bool {
		return false;
	}

	public function interact(player:Player, item:Item, attackDir:Int):Bool {
		return item.interact(player, this, attackDir);
	}

	public function use(player:Player, attackDir:Int):Bool {
		return false;
	}

	public function getLightRadius():Int {
		return 0;
	}
}

