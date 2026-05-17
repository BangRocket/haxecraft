package engine.gfx;

class CompositePart {
	public var id:SpriteId;
	public var dx:Int;
	public var dy:Int;
	public var flip:Int;

	public function new(id:SpriteId, dx:Int, dy:Int, flip:Int = 0) {
		this.id = id;
		this.dx = dx;
		this.dy = dy;
		this.flip = flip;
	}
}

class CompositeSprite {
	public var name:String;
	public var w:Int;
	public var h:Int;
	public var anchorX:Int;
	public var anchorY:Int;
	public var parts:Array<CompositePart>;

	public function new(name:String, w:Int, h:Int, ax:Int, ay:Int, parts:Array<CompositePart>) {
		this.name = name;
		this.w = w;
		this.h = h;
		this.anchorX = ax;
		this.anchorY = ay;
		this.parts = parts;
	}
}
