package gfx;

import haxe.ds.Vector;
import hxd.Pixels;

class SpriteSheet {
	public var width:Int;
	public var height:Int;
	public var pixels:Vector<Int>;
	public var rgbaPixels:Vector<Int>;
	public var grayscaleMask:Vector<Bool>;

	public function new(image:Pixels) {
		width = image.width;
		height = image.height;
		var n = width * height;
		pixels = new Vector<Int>(n);
		rgbaPixels = new Vector<Int>(n);
		grayscaleMask = new Vector<Bool>(n);
		for (y in 0...height) {
			for (x in 0...width) {
				var i = x + y * width;
				var rgba = image.getPixel(x, y);
				var r = (rgba >> 16) & 0xff;
				var g = (rgba >> 8) & 0xff;
				var b = rgba & 0xff;
				rgbaPixels[i] = rgba;
				grayscaleMask[i] = r == g && g == b;
				pixels[i] = b >> 6;
			}
		}
	}
}
