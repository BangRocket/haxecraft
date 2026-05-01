package gfx;

class Screen {
	public var xOffset:Int;
	public var yOffset:Int;

	public static inline var BIT_MIRROR_X = 0x01;
	public static inline var BIT_MIRROR_Y = 0x02;

	public var w:Int;
	public var h:Int;
	public var pixels:Array<Int>;
	public var light:Array<Int>;

	var sheet:SpriteSheet;
	public var colorSheet:SpriteSheet;
	public var terrainSheet:SpriteSheet;
	public var itemSheet:SpriteSheet;
	public var uiSheet:SpriteSheet;
	public var playerSheet:SpriteSheet;
	public var monsterSheet:SpriteSheet;

	private static inline var TILE_STRIDE = 32;

	public function new(w:Int, h:Int, sheet:SpriteSheet, ?colorSheet:SpriteSheet) {
		this.sheet = sheet;
		this.colorSheet = colorSheet;
		this.w = w;
		this.h = h;
		pixels = [];
		light = [];
		for (i in 0...w * h) {
			pixels.push(0xFF000000);
			light.push(0);
		}
	}

	public function setCategorySheets(terrainSheet:SpriteSheet, itemSheet:SpriteSheet, uiSheet:SpriteSheet, playerSheet:SpriteSheet, monsterSheet:SpriteSheet):Void {
		this.terrainSheet = terrainSheet;
		this.itemSheet = itemSheet;
		this.uiSheet = uiSheet;
		this.playerSheet = playerSheet;
		this.monsterSheet = monsterSheet;
	}

	public function clear(color:Int) {
		var rgba = color == 0 ? 0xFF000000 : color;
		for (i in 0...pixels.length) {
			pixels[i] = rgba;
		}
	}

	public function clearLight(brightness:Int) {
		for (i in 0...light.length) {
			light[i] = brightness;
		}
	}

	public function render(xp:Int, yp:Int, tile:Int, bits:Int, ?sourceSheet:SpriteSheet) {
		var mapping = sourceSheet != null ? {sheet: sourceSheet, tileOffsetX: 0, tileOffsetY: 0} : pickSheetForTile(tile);
		var s = mapping.sheet;
		xp -= xOffset;
		yp -= yOffset;
		var mirrorX = (bits & BIT_MIRROR_X) > 0;
		var mirrorY = (bits & BIT_MIRROR_Y) > 0;

		var xTile = (tile % TILE_STRIDE) - mapping.tileOffsetX;
		var yTile = Std.int(tile / TILE_STRIDE) - mapping.tileOffsetY;
		var maxTileX = Std.int(s.width / 8);
		var maxTileY = Std.int(s.height / 8);
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

	function pickSheetForTile(tile:Int):{sheet:SpriteSheet, tileOffsetX:Int, tileOffsetY:Int} {
		var tileRow = Std.int(tile / 32);
		if (isTerrainRow(tileRow) && terrainSheet != null) return {sheet: terrainSheet, tileOffsetX: 0, tileOffsetY: 0};
		if (isItemRow(tileRow) && itemSheet != null) return {sheet: itemSheet, tileOffsetX: 0, tileOffsetY: 4};
		if (isUiRow(tileRow) && uiSheet != null) return {sheet: uiSheet, tileOffsetX: 0, tileOffsetY: 6};
		if (isPlayerRow(tileRow) && playerSheet != null) return {sheet: playerSheet, tileOffsetX: 0, tileOffsetY: 14};
		if (isMonsterRow(tileRow) && monsterSheet != null) return {sheet: monsterSheet, tileOffsetX: 0, tileOffsetY: 18};
		return {sheet: sheet, tileOffsetX: 0, tileOffsetY: 0};
	}

	inline function isTerrainRow(tileRow:Int):Bool {
		return (tileRow >= 0 && tileRow <= 3) || tileRow == 8 || tileRow == 9;
	}

	inline function isItemRow(tileRow:Int):Bool {
		return (tileRow >= 4 && tileRow <= 5) || tileRow == 10;
	}

	inline function isUiRow(tileRow:Int):Bool {
		return (tileRow >= 6 && tileRow <= 7) || (tileRow >= 11 && tileRow <= 13) || tileRow == 30;
	}

	inline function isPlayerRow(tileRow:Int):Bool {
		return tileRow >= 14 && tileRow <= 17;
	}

	inline function isMonsterRow(tileRow:Int):Bool {
		return tileRow >= 18 && tileRow <= 29;
	}

	public function setOffset(xOffset:Int, yOffset:Int) {
		this.xOffset = xOffset;
		this.yOffset = yOffset;
	}

	var dither:Array<Int> = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

	public function overlay(screen2:Screen, xa:Int, ya:Int) {
		var oLight = screen2.light;
		var i = 0;
		for (y in 0...h) {
			for (x in 0...w) {
				if (Std.int(oLight[i] / 10) <= dither[((x + xa) & 3) + ((y + ya) & 3) * 4]) {
					pixels[i] = 0xFF000000;
				}
				i++;
			}
		}
	}

	public function renderLight(x:Int, y:Int, r:Int) {
		x -= xOffset;
		y -= yOffset;
		var x0 = x - r;
		var x1 = x + r;
		var y0 = y - r;
		var y1 = y + r;

		if (x0 < 0) x0 = 0;
		if (y0 < 0) y0 = 0;
		if (x1 > w) x1 = w;
		if (y1 > h) y1 = h;
		for (yy in y0...y1) {
			var yd = yy - y;
			yd = yd * yd;
			for (xx in x0...x1) {
				var xd = xx - x;
				var dist = xd * xd + yd;
				if (dist <= r * r) {
					var br = 255 - Std.int(dist * 255 / (r * r));
					if (light[xx + yy * w] < br) {
						light[xx + yy * w] = br;
					}
				}
			}
		}
	}
}
