package game.item.resource;

import engine.item.resource.Resource;

import game.entity.Player;
import engine.level.Level;
import engine.level.tile.Tile;

class PlantableResource extends Resource {
	var sourceTiles:Array<Tile>;
	var targetTile:Tile;

	public function new(name:String, sprite:Int, color:Int, targetTile:Tile, ...sourceTiles:Tile) {
		super(name, sprite, color);
		this.sourceTiles = sourceTiles;
		this.targetTile = targetTile;
	}

	override public function interactOn(tile:Tile, level:Level, xt:Int, yt:Int, player:Player, attackDir:Int):Bool {
		if (sourceTiles.contains(tile)) {
			level.setTile(xt, yt, targetTile, 0);
			return true;
		}
		return false;
	}
}
