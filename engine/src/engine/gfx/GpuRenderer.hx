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

	var atlasPixels:Pixels;
	var atlasTexture:Texture;
	var atlasTile:H2dTile;
	var atlasDirty:Bool = false;
	var nextSlot:Int = 0;

	// Cache: per-sheet (tint, IntMap). Splitting by tint avoids packing a
	// 24-bit color into the 32-bit IntMap key alongside tile/bits/colors.
	// Inner Int key layout (within a single tint bucket):
	//   bits  0..9   tileId          (≤ 1024)
	//   bits 10..11  flip bits
	//   bits 12..31  colors          (palette word — up to 20 bits used)
	// `tint` is almost always 0 in haxecraft, so the outer Map mostly has one
	// entry per sheet and this stays a near-pure IntMap lookup.
	var cacheMap:Map<SpriteSheet, Map<Int, haxe.ds.IntMap<H2dTile>>>;

	public var tileGroup:TileGroup;

	var overlayPixels:Pixels;
	var overlayTexture:Texture;
	public var overlayBitmap:Bitmap;
	var screenW:Int;
	var screenH:Int;

	static var DITHER:Array<Int> = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

	public function new(w:Int, h:Int, scene:h2d.Scene) {
		this.screenW = w;
		this.screenH = h;

		atlasPixels = Pixels.alloc(ATLAS_SIZE, ATLAS_SIZE, PixelFormat.RGBA);
		atlasTexture = new Texture(ATLAS_SIZE, ATLAS_SIZE, [TextureFlags.Dynamic], h3d.mat.Texture.nativeFormat);
		atlasTile = H2dTile.fromTexture(atlasTexture);

		cacheMap = new Map();

		tileGroup = new TileGroup(atlasTile, scene);
		tileGroup.smooth = false;

		overlayPixels = Pixels.alloc(w, h, PixelFormat.RGBA);
		overlayTexture = new Texture(w, h, [TextureFlags.Dynamic], h3d.mat.Texture.nativeFormat);
		overlayBitmap = new Bitmap(H2dTile.fromTexture(overlayTexture), scene);
		overlayBitmap.smooth = false;
		overlayBitmap.visible = false;
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

	public function addTile(xp:Int, yp:Int, tileId:Int, colors:Int, bits:Int, tint:Int, s:SpriteSheet) {
		var sheetCache = cacheMap.get(s);
		if (sheetCache == null) {
			sheetCache = new Map();
			cacheMap.set(s, sheetCache);
		}
		var tintCache = sheetCache.get(tint);
		if (tintCache == null) {
			tintCache = new haxe.ds.IntMap();
			sheetCache.set(tint, tintCache);
		}
		var key = (tileId & 0x3FF) | ((bits & 3) << 10) | (colors << 12);
		var tile = tintCache.get(key);
		if (tile == null) {
			tile = renderCacheTile(s, tileId, colors, bits, tint);
			tintCache.set(key, tile);
		}
		tileGroup.add(xp, yp, tile);
	}

	function renderCacheTile(s:SpriteSheet, tileId:Int, colors:Int, bits:Int, tint:Int):H2dTile {
		if (nextSlot >= MAX_SLOTS) return atlasTile.sub(0, 0, TILE_SIZE, TILE_SIZE);

		var slot = nextSlot++;
		var ax = (slot % TILES_PER_ROW) * TILE_SIZE;
		var ay = Std.int(slot / TILES_PER_ROW) * TILE_SIZE;

		var mirrorX = (bits & 0x01) > 0;
		var mirrorY = (bits & 0x02) > 0;
		var xTile = tileId & 31;
		var yTile = tileId >> 5;
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

				// Grayscale pixels: palette lookup
				if (s.grayscaleMask[srcIdx]) {
					var palIdx = (colors >> (s.pixels[srcIdx] * 8)) & 255;
					if (palIdx < 255) {
						atlasPixels.setPixel(ax + px, ay + py, Screen.palette[palIdx]);
					} else {
						atlasPixels.setPixel(ax + px, ay + py, 0x00000000);
					}
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
