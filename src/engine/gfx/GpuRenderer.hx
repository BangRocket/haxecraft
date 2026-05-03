package engine.gfx;

import haxe.ds.Vector;
import h2d.Bitmap;
import h2d.Tile as H2dTile;
import h2d.TileGroup;
import h3d.mat.Data.TextureFlags;
import h3d.mat.Texture;
import hxd.PixelFormat;
import hxd.Pixels;

class GpuRenderer {
	static inline var ATLAS_SIZE = 1024;
	static inline var TILE_SIZE = 8;
	static inline var TILES_PER_ROW = 128;
	static inline var MAX_SLOTS = 16384;
	static inline var MAX_TILE_ROW = 32;

	var atlasPixels:Pixels;
	var atlasTexture:Texture;
	var atlasTile:H2dTile;
	var atlasDirty:Bool = false;
	var nextSlot:Int = 0;

	// Cache: key = tileId | (bits << 10) | (tint << 12), value = atlas sub-tile
	// For zero-tint tiles (vast majority), key fits in 12 bits
	var cacheMap:haxe.ds.IntMap<H2dTile>;

	// Sheet dispatch table (mirrors Screen's)
	var rowSheet:Vector<SpriteSheet>;
	var rowOffsetY:Vector<Int>;
	var defaultSheet:SpriteSheet;

	public var tileGroup:TileGroup;

	var overlayPixels:Pixels;
	var overlayTexture:Texture;
	public var overlayBitmap:Bitmap;
	var screenW:Int;
	var screenH:Int;

	static var DITHER:Array<Int> = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

	public function new(w:Int, h:Int, iconSheet:SpriteSheet, ?spriteSheet:SpriteSheet, scene:h2d.Scene) {
		this.defaultSheet = iconSheet;
		this.screenW = w;
		this.screenH = h;

		rowSheet = new Vector<SpriteSheet>(MAX_TILE_ROW);
		rowOffsetY = new Vector<Int>(MAX_TILE_ROW);
		for (i in 0...MAX_TILE_ROW) {
			rowSheet[i] = iconSheet;
			rowOffsetY[i] = 0;
		}

		atlasPixels = Pixels.alloc(ATLAS_SIZE, ATLAS_SIZE, PixelFormat.RGBA);
		atlasTexture = new Texture(ATLAS_SIZE, ATLAS_SIZE, [TextureFlags.Dynamic], h3d.mat.Texture.nativeFormat);
		atlasTile = H2dTile.fromTexture(atlasTexture);

		cacheMap = new haxe.ds.IntMap<H2dTile>();

		tileGroup = new TileGroup(atlasTile, scene);
		tileGroup.smooth = false;

		overlayPixels = Pixels.alloc(w, h, PixelFormat.RGBA);
		overlayTexture = new Texture(w, h, [TextureFlags.Dynamic], h3d.mat.Texture.nativeFormat);
		overlayBitmap = new Bitmap(H2dTile.fromTexture(overlayTexture), scene);
		overlayBitmap.smooth = false;
		overlayBitmap.visible = false;
	}

	public function setCategorySheets(terrainSheet:SpriteSheet, itemSheet:SpriteSheet, uiSheet:SpriteSheet, playerSheet:SpriteSheet, monsterSheet:SpriteSheet):Void {
		for (row in 0...MAX_TILE_ROW) {
			var s = defaultSheet;
			var oy = 0;
			if (((row >= 0 && row <= 3) || row == 8 || row == 9) && terrainSheet != null) {
				s = terrainSheet; oy = 0;
			} else if (((row >= 4 && row <= 5) || row == 10) && itemSheet != null) {
				s = itemSheet; oy = 4;
			} else if (((row >= 6 && row <= 7) || (row >= 11 && row <= 13) || row == 30) && uiSheet != null) {
				s = uiSheet; oy = 6;
			} else if ((row >= 14 && row <= 17) && playerSheet != null) {
				s = playerSheet; oy = 14;
			} else if ((row >= 18 && row <= 29) && monsterSheet != null) {
				s = monsterSheet; oy = 18;
			}
			rowSheet[row] = s;
			rowOffsetY[row] = oy;
		}
		// Invalidate cache since sheets changed
		cacheMap = new haxe.ds.IntMap<H2dTile>();
		nextSlot = 0;
	}

	public inline function beginFrame() {
		tileGroup.clear();
	}

	public function endFrame() {
		if (atlasDirty) {
			atlasTexture.uploadPixels(atlasPixels);
			atlasDirty = false;
		}
	}

	public function addTile(xp:Int, yp:Int, tileId:Int, bits:Int, tint:Int) {
		var key = tileId | ((bits & 3) << 10) | ((tint & 0xFFFFFF) << 12);
		var tile = cacheMap.get(key);
		if (tile == null) {
			tile = renderCacheTile(tileId, bits, tint);
			cacheMap.set(key, tile);
		}
		tileGroup.add(xp, yp, tile);
	}

	function renderCacheTile(tileId:Int, bits:Int, tint:Int):H2dTile {
		if (nextSlot >= MAX_SLOTS) return atlasTile.sub(0, 0, TILE_SIZE, TILE_SIZE);

		var slot = nextSlot++;
		var ax = (slot % TILES_PER_ROW) * TILE_SIZE;
		var ay = Std.int(slot / TILES_PER_ROW) * TILE_SIZE;

		var row = tileId >> 5;
		var s:SpriteSheet;
		var offY:Int;
		if (row >= 0 && row < MAX_TILE_ROW) {
			s = rowSheet[row];
			offY = rowOffsetY[row];
		} else {
			s = defaultSheet;
			offY = 0;
		}

		var mirrorX = (bits & 0x01) > 0;
		var mirrorY = (bits & 0x02) > 0;
		var xTile = tileId & 31;
		var yTile = (tileId >> 5) - offY;
		var maxTileX = s.width >> 3;
		var maxTileY = s.height >> 3;

		if (xTile < 0 || yTile < 0 || xTile >= maxTileX || yTile >= maxTileY) {
			for (py in 0...TILE_SIZE)
				for (px in 0...TILE_SIZE)
					atlasPixels.setPixel(ax + px, ay + py, 0x00000000);
			atlasDirty = true;
			return atlasTile.sub(ax, ay, TILE_SIZE, TILE_SIZE);
		}

		var toffs = xTile * 8 + yTile * 8 * s.width;

		for (py in 0...8) {
			var ys = mirrorY ? 7 - py : py;
			for (px in 0...8) {
				var xs = mirrorX ? 7 - px : px;
				var srcIdx = xs + ys * s.width + toffs;
				var rgba = s.rgbaPixels[srcIdx];
				var alpha = (rgba >>> 24) & 255;
				if (alpha == 0) {
					atlasPixels.setPixel(ax + px, ay + py, 0x00000000);
					continue;
				}

				if (tint != 0) {
					var sr = (rgba >> 16) & 255;
					var sg = (rgba >> 8) & 255;
					var sb = rgba & 255;
					var tr = (tint >> 16) & 255;
					var tg = (tint >> 8) & 255;
					var tb = tint & 255;
					rgba = (alpha << 24) | (Std.int((sr * tr) / 255) << 16) | (Std.int((sg * tg) / 255) << 8) | Std.int((sb * tb) / 255);
				}

				atlasPixels.setPixel(ax + px, ay + py, rgba);
			}
		}

		atlasDirty = true;
		return atlasTile.sub(ax, ay, TILE_SIZE, TILE_SIZE);
	}

	public function buildOverlay(lightScreen:Screen, xa:Int, ya:Int) {
		var oLight = lightScreen.light;
		var oLightW = lightScreen.lightW;
		var bytes = overlayPixels.bytes;
		var black:Int = 0xFF000000;
		for (y in 0...screenH) {
			var ly = y >> 2;
			for (x in 0...screenW) {
				var lx = x >> 2;
				var bright = oLight[lx + ly * oLightW];
				var dark = Std.int(bright / 10) <= DITHER[((x + xa) & 3) + ((y + ya) & 3) * 4];
				bytes.setInt32((x + y * screenW) << 2, dark ? black : 0);
			}
		}
		overlayTexture.uploadPixels(overlayPixels);
		overlayBitmap.visible = true;
	}

	public function hideOverlay() {
		overlayBitmap.visible = false;
	}

	public function setScale(sx:Float, sy:Float) {
		tileGroup.scaleX = sx;
		tileGroup.scaleY = sy;
		overlayBitmap.scaleX = sx;
		overlayBitmap.scaleY = sy;
	}
}
