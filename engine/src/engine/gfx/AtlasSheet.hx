package engine.gfx;

class AtlasSheet {
	public var name:String;
	public var atlas:SpriteAtlas;
	public var pixelOffsetX:Int;
	public var pixelOffsetY:Int;
	public var spriteW:Int;
	public var spriteH:Int;
	public var cols:Int;
	public var rows:Int;

	public function new(name:String, atlas:SpriteAtlas, ox:Int, oy:Int, sw:Int, sh:Int, cols:Int, rows:Int) {
		this.name = name;
		this.atlas = atlas;
		this.pixelOffsetX = ox;
		this.pixelOffsetY = oy;
		this.spriteW = sw;
		this.spriteH = sh;
		this.cols = cols;
		this.rows = rows;
	}

	public inline function spriteCount():Int return cols * rows;
}
