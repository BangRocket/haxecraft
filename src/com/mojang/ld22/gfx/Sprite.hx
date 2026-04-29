package com.mojang.ld22.gfx;

class Sprite {
	public var x:Int;
	public var y:Int;
	public var img:Int;
	public var col:Int;
	public var bits:Int;

	public function new(x:Int, y:Int, img:Int, col:Int, bits:Int) {
		this.x = x;
		this.y = y;
		this.img = img;
		this.col = col;
		this.bits = bits;
	}
}
