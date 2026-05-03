package engine.gfx;

import haxe.ds.Vector;

class Screen {
	public var xOffset:Int;
	public var yOffset:Int;

	public static inline var BIT_MIRROR_X = 0x01;
	public static inline var BIT_MIRROR_Y = 0x02;
	public static inline var LIGHT_SCALE = 4;

	private static inline var TILE_STRIDE = 32;
	private static inline var MAX_TILE_ROW = 32;

	public var w:Int;
	public var h:Int;
	public var pixels:Array<Int>;
	public var light:Vector<Int>;
	public var lightW:Int;
	public var lightH:Int;

	var sheet:SpriteSheet;
	public var colorSheet:SpriteSheet;
	public var terrainSheet:SpriteSheet;
	public var itemSheet:SpriteSheet;
	public var uiSheet:SpriteSheet;
	public var playerSheet:SpriteSheet;
	public var monsterSheet:SpriteSheet;
	public var gpu:GpuRenderer;

	// Per-tile-row dispatch table
	var rowSheet:Vector<SpriteSheet>;
	var rowOffsetY:Vector<Int>;

	public function new(w:Int, h:Int, sheet:SpriteSheet, ?colorSheet:SpriteSheet) {
		this.sheet = sheet;
		this.colorSheet = colorSheet;
		this.w = w;
		this.h = h;
		lightW = (w + LIGHT_SCALE - 1) >> 2;
		lightH = (h + LIGHT_SCALE - 1) >> 2;
		pixels = [];
		light = new Vector<Int>(lightW * lightH);
		for (i in 0...w * h) {
			pixels.push(0xFF000000);
		}
		rowSheet = new Vector<SpriteSheet>(MAX_TILE_ROW);
		rowOffsetY = new Vector<Int>(MAX_TILE_ROW);
		rebuildSheetTable();
	}

	public function setCategorySheets(terrainSheet:SpriteSheet, itemSheet:SpriteSheet, uiSheet:SpriteSheet, playerSheet:SpriteSheet, monsterSheet:SpriteSheet):Void {
		this.terrainSheet = terrainSheet;
		this.itemSheet = itemSheet;
		this.uiSheet = uiSheet;
		this.playerSheet = playerSheet;
		this.monsterSheet = monsterSheet;
		rebuildSheetTable();
	}

	function rebuildSheetTable():Void {
		for (row in 0...MAX_TILE_ROW) {
			var s:SpriteSheet = sheet;
			var oy:Int = 0;
			if (((row >= 0 && row <= 3) || row == 8 || row == 9) && terrainSheet != null) {
				s = terrainSheet;
				oy = 0;
			} else if (((row >= 4 && row <= 5) || row == 10) && itemSheet != null) {
				s = itemSheet;
				oy = 4;
			} else if (((row >= 6 && row <= 7) || (row >= 11 && row <= 13) || row == 30) && uiSheet != null) {
				s = uiSheet;
				oy = 6;
			} else if ((row >= 14 && row <= 17) && playerSheet != null) {
				s = playerSheet;
				oy = 14;
			} else if ((row >= 18 && row <= 29) && monsterSheet != null) {
				s = monsterSheet;
				oy = 18;
			}
			rowSheet[row] = s;
			rowOffsetY[row] = oy;
		}
	}

	public function clear(color:Int) {
		var rgba = color == 0 ? 0xFF000000 : color;
		var n = pixels.length;
		for (i in 0...n) {
			pixels[i] = rgba;
		}
	}

	public function clearLight(brightness:Int) {
		for (i in 0...light.length) {
			light[i] = brightness;
		}
	}

	public function render(xp:Int, yp:Int, tile:Int, bits:Int, ?sourceSheet:SpriteSheet, ?tint:Int = 0) {
		var s:SpriteSheet;
		var offY:Int;
		if (sourceSheet != null) {
			s = sourceSheet;
			offY = 0;
		} else {
			var row = tile >> 5;
			if (row < 0 || row >= MAX_TILE_ROW) return;
			s = rowSheet[row];
			offY = rowOffsetY[row];
		}
		xp -= xOffset;
		yp -= yOffset;
		var mirrorX = (bits & BIT_MIRROR_X) > 0;
		var mirrorY = (bits & BIT_MIRROR_Y) > 0;

		var xTile = tile & (TILE_STRIDE - 1);
		var yTile = (tile >> 5) - offY;
		var maxTileX = s.width >> 3;
		var maxTileY = s.height >> 3;
		if (xTile < 0 || yTile < 0 || xTile >= maxTileX || yTile >= maxTileY) return;
		var toffs = xTile * 8 + yTile * 8 * s.width;

		for (y in 0...8) {
			var ys = y;
			if (mirrorY) ys = 7 - y;
			if (y + yp < 0 || y + yp >= h) continue;
			for (x in 0...8) {
				if (x + xp < 0 || x + xp >= w) continue;

				var xs = x;
				if (mirrorX) xs = 7 - x;
				var src = xs + ys * s.width + toffs;
				var rgba = s.rgbaPixels[src];
				var alpha = (rgba >>> 24) & 255;
				if (alpha == 0) continue;

				if (tint != 0) {
					var sr = (rgba >> 16) & 255;
					var sg = (rgba >> 8) & 255;
					var sb = rgba & 255;
					var tr = (tint >> 16) & 255;
					var tg = (tint >> 8) & 255;
					var tb = tint & 255;
					rgba = (alpha << 24) | (Std.int((sr * tr) / 255) << 16) | (Std.int((sg * tg) / 255) << 8) | Std.int((sb * tb) / 255);
				}

				var dst = (x + xp) + (y + yp) * w;
				if (alpha == 255) {
					pixels[dst] = rgba;
				} else {
					var dstRgba = pixels[dst];
					var dstR = (dstRgba >> 16) & 255;
					var dstG = (dstRgba >> 8) & 255;
					var dstB = dstRgba & 255;
					var invA = 255 - alpha;
					var srcR = (rgba >> 16) & 255;
					var srcG = (rgba >> 8) & 255;
					var srcB = rgba & 255;
					var outR = Std.int((srcR * alpha + dstR * invA) / 255);
					var outG = Std.int((srcG * alpha + dstG * invA) / 255);
					var outB = Std.int((srcB * alpha + dstB * invA) / 255);
					pixels[dst] = 0xFF000000 | (outR << 16) | (outG << 8) | outB;
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
		if (gpu != null) {
			gpu.buildOverlay(screen2, xa, ya);
			return;
		}
		var oLight = screen2.light;
		var oLightW = screen2.lightW;
		var i = 0;
		for (y in 0...h) {
			var ly = y >> 2;
			for (x in 0...w) {
				var lx = x >> 2;
				if (Std.int(oLight[lx + ly * oLightW] / 10) <= dither[((x + xa) & 3) + ((y + ya) & 3) * 4]) {
					pixels[i] = 0xFF000000;
				}
				i++;
			}
		}
	}

	public function renderLight(x:Int, y:Int, r:Int) {
		x -= xOffset;
		y -= yOffset;
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
