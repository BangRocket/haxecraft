package gfx;

class Screen {
	public var xOffset:Int;
	public var yOffset:Int;

	public static inline var BIT_MIRROR_X = 0x01;
	public static inline var BIT_MIRROR_Y = 0x02;
	public static inline var LIGHT_SCALE = 4;

	public var w:Int;
	public var h:Int;
	public var pixels:Array<Int>;
	public var colorPixels:Array<Int>;
	public var light:Array<Int>;
	public var lightW:Int;
	public var lightH:Int;

	var sheet:SpriteSheet;
	var colorSheet:SpriteSheet;

	public function new(w:Int, h:Int, sheet:SpriteSheet, ?colorSheet:SpriteSheet) {
		this.sheet = sheet;
		this.colorSheet = colorSheet;
		this.w = w;
		this.h = h;
		lightW = (w + LIGHT_SCALE - 1) >> 2;
		lightH = (h + LIGHT_SCALE - 1) >> 2;
		pixels = [];
		colorPixels = [];
		light = [];
		for (i in 0...w * h) {
			pixels.push(0);
			colorPixels.push(-1);
		}
		for (i in 0...lightW * lightH) {
			light.push(0);
		}
	}

	public function clear(color:Int) {
		for (i in 0...pixels.length) {
			pixels[i] = color;
			colorPixels[i] = -1;
		}
	}

	public function clearLight(brightness:Int) {
		for (i in 0...light.length) {
			light[i] = brightness;
		}
	}

	public function render(xp:Int, yp:Int, tile:Int, colors:Int, bits:Int) {
		xp -= xOffset;
		yp -= yOffset;
		var mirrorX = (bits & BIT_MIRROR_X) > 0;
		var mirrorY = (bits & BIT_MIRROR_Y) > 0;

		var xTile = tile % 32;
		var yTile = Std.int(tile / 32);
		var toffs = xTile * 8 + yTile * 8 * sheet.width;

		for (y in 0...8) {
			var ys = y;
			if (mirrorY) ys = 7 - y;
			if (y + yp < 0 || y + yp >= h) continue;
			for (x in 0...8) {
				if (x + xp < 0 || x + xp >= w) continue;

				var xs = x;
				if (mirrorX) xs = 7 - x;
				var col = (colors >> (sheet.pixels[xs + ys * sheet.width + toffs] * 8)) & 255;
				if (col < 255) {
					var dst = (x + xp) + (y + yp) * w;
					pixels[dst] = col;
					colorPixels[dst] = -1;
				}
			}
		}
	}

	public function renderFullColor(xp:Int, yp:Int, tile:Int, colors:Int, bits:Int) {
		var sourceSheet = colorSheet != null ? colorSheet : sheet;
		xp -= xOffset;
		yp -= yOffset;
		var mirrorX = (bits & BIT_MIRROR_X) > 0;
		var mirrorY = (bits & BIT_MIRROR_Y) > 0;

		var xTile = tile % 32;
		var yTile = Std.int(tile / 32);
		var toffs = xTile * 8 + yTile * 8 * sourceSheet.width;

		for (y in 0...8) {
			var ys = y;
			if (mirrorY) ys = 7 - y;
			if (y + yp < 0 || y + yp >= h) continue;
			for (x in 0...8) {
				if (x + xp < 0 || x + xp >= w) continue;

				var xs = x;
				if (mirrorX) xs = 7 - x;
				var src = xs + ys * sourceSheet.width + toffs;
				var dst = (x + xp) + (y + yp) * w;
				var rgba = sourceSheet.rgbaPixels[src];
				var alpha = (rgba >>> 24) & 255;
				if (alpha == 0) continue;

				if (sourceSheet.grayscaleMask[src]) {
					var col = (colors >> (sourceSheet.pixels[src] * 8)) & 255;
					if (col < 255) {
						pixels[dst] = col;
						colorPixels[dst] = -1;
					}
				} else {
					colorPixels[dst] = rgba;
				}
			}
		}
	}

	public inline function setOffset(xOffset:Int, yOffset:Int) {
		this.xOffset = xOffset;
		this.yOffset = yOffset;
	}

	var dither:Array<Int> = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

	public function overlay(screen2:Screen, xa:Int, ya:Int) {
		var oLight = screen2.light;
		var oLightW = screen2.lightW;
		var i = 0;
		for (y in 0...h) {
			var ly = y >> 2;
			for (x in 0...w) {
				var lx = x >> 2;
				if (Std.int(oLight[lx + ly * oLightW] / 10) <= dither[((x + xa) & 3) + ((y + ya) & 3) * 4]) {
					pixels[i] = 0;
					colorPixels[i] = -1;
				}
				i++;
			}
		}
	}

	public function renderLight(x:Int, y:Int, r:Int) {
		x -= xOffset;
		y -= yOffset;
		// Scale to light-buffer coordinates
		var lx = x >> 2;
		var ly = y >> 2;
		var lr = (r + LIGHT_SCALE - 1) >> 2;
		var x0 = lx - lr;
		var x1 = lx + lr;
		var y0 = ly - lr;
		var y1 = ly + lr;

		if (x0 < 0) x0 = 0;
		if (y0 < 0) y0 = 0;
		if (x1 > lightW) x1 = lightW;
		if (y1 > lightH) y1 = lightH;
		var rSq = lr * lr;
		for (yy in y0...y1) {
			var yd = yy - ly;
			yd = yd * yd;
			for (xx in x0...x1) {
				var xd = xx - lx;
				var dist = xd * xd + yd;
				if (dist <= rSq) {
					var br = 255 - Std.int(dist * 255 / rSq);
					var idx = xx + yy * lightW;
					if (light[idx] < br) {
						light[idx] = br;
					}
				}
			}
		}
	}
}
