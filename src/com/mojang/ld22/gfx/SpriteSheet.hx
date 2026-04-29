package com.mojang.ld22.gfx;

import hxd.Pixels;

class SpriteSheet {
	public var width:Int;
	public var height:Int;
	public var pixels:Array<Int>;

	public function new(image:Pixels) {
		width = image.width;
		height = image.height;
		pixels = [];
		var src = image.bytes;
		for (i in 0...width * height) {
			var b = src.get(i * 4);
			pixels[i] = (b & 0xff) >> 6;
		}
	}
}
