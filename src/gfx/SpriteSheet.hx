package gfx;

import hxd.Pixels;

class SpriteSheet {
	public var width:Int;
	public var height:Int;
	public var pixels:Array<Int>;
	public var rgbaPixels:Array<Int>;
	public var grayscaleMask:Array<Bool>;

	public function new(image:Pixels) {
		width = image.width;
		height = image.height;
		pixels = [];
		rgbaPixels = [];
		grayscaleMask = [];
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

	public static function fromRows(source:SpriteSheet, rows:Array<Int>):SpriteSheet {
		var image = Pixels.alloc(source.width, source.height, hxd.PixelFormat.BGRA);
		var keepRows = new Map<Int, Bool>();
		for (r in rows) {
			keepRows.set(r, true);
		}

		for (y in 0...source.height) {
			var tileRow = Std.int(y / 8);
			var includeRow = keepRows.exists(tileRow);
			for (x in 0...source.width) {
				var i = x + y * source.width;
				var rgba = includeRow ? source.rgbaPixels[i] : 0x00000000;
				image.setPixel(x, y, rgba);
			}
		}
		return new SpriteSheet(image);
	}
}
