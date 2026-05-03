package gfx;

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
	static inline var CACHE_SIZE = 8192;

	var palette:Array<Int>;
	var sheet:SpriteSheet;
	var colorSheet:SpriteSheet;

	var atlasPixels:Pixels;
	var atlasTexture:Texture;
	var atlasTile:H2dTile;
	var atlasDirty:Bool = false;
	var nextSlot:Int = 0;

	var cache:Vector<haxe.ds.IntMap<H2dTile>>;

	public var tileGroup:TileGroup;

	var overlayPixels:Pixels;
	var overlayTexture:Texture;
	public var overlayBitmap:Bitmap;
	var screenW:Int;
	var screenH:Int;

	static var DITHER:Array<Int> = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

	public function new(w:Int, h:Int, palette:Array<Int>, sheet:SpriteSheet, ?colorSheet:SpriteSheet, scene:h2d.Scene) {
		this.palette = palette;
		this.sheet = sheet;
		this.colorSheet = colorSheet;
		this.screenW = w;
		this.screenH = h;

		atlasPixels = Pixels.alloc(ATLAS_SIZE, ATLAS_SIZE, PixelFormat.RGBA);
		atlasTexture = new Texture(ATLAS_SIZE, ATLAS_SIZE, [TextureFlags.Dynamic], h3d.mat.Texture.nativeFormat);
		atlasTile = H2dTile.fromTexture(atlasTexture);

		cache = new Vector<haxe.ds.IntMap<H2dTile>>(CACHE_SIZE);

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

	public function addTile(xp:Int, yp:Int, tileId:Int, colors:Int, bits:Int) {
		var key = tileId | ((bits & 3) << 10);
		if (key < 0 || key >= CACHE_SIZE) return;
		var map = cache[key];
		if (map == null) {
			map = new haxe.ds.IntMap<H2dTile>();
			cache[key] = map;
		}
		var tile = map.get(colors);
		if (tile == null) {
			tile = renderCacheTile(tileId, colors, bits, false);
			map.set(colors, tile);
		}
		tileGroup.add(xp, yp, tile);
	}

	public function addFullColorTile(xp:Int, yp:Int, tileId:Int, colors:Int, bits:Int) {
		var key = tileId | ((bits & 3) << 10) | (1 << 12);
		if (key < 0 || key >= CACHE_SIZE) return;
		var map = cache[key];
		if (map == null) {
			map = new haxe.ds.IntMap<H2dTile>();
			cache[key] = map;
		}
		var tile = map.get(colors);
		if (tile == null) {
			tile = renderCacheTile(tileId, colors, bits, true);
			map.set(colors, tile);
		}
		tileGroup.add(xp, yp, tile);
	}

	function renderCacheTile(tileId:Int, colors:Int, bits:Int, fullColor:Bool):H2dTile {
		if (nextSlot >= MAX_SLOTS) return atlasTile.sub(0, 0, TILE_SIZE, TILE_SIZE);

		var slot = nextSlot++;
		var ax = (slot % TILES_PER_ROW) * TILE_SIZE;
		var ay = Std.int(slot / TILES_PER_ROW) * TILE_SIZE;

		var src = fullColor ? (colorSheet != null ? colorSheet : sheet) : sheet;
		var mirrorX = (bits & 0x01) > 0;
		var mirrorY = (bits & 0x02) > 0;
		var xTile = tileId & 31;
		var yTile = tileId >> 5;
		var maxTileX = src.width >> 3;
		var maxTileY = src.height >> 3;

		if (xTile < 0 || yTile < 0 || xTile >= maxTileX || yTile >= maxTileY) {
			for (py in 0...TILE_SIZE)
				for (px in 0...TILE_SIZE)
					atlasPixels.setPixel(ax + px, ay + py, 0x00000000);
			atlasDirty = true;
			return atlasTile.sub(ax, ay, TILE_SIZE, TILE_SIZE);
		}

		var toffs = xTile * 8 + yTile * 8 * src.width;

		for (py in 0...8) {
			var ys = mirrorY ? 7 - py : py;
			for (px in 0...8) {
				var xs = mirrorX ? 7 - px : px;
				var srcIdx = xs + ys * src.width + toffs;
				var rgba:Int;

				if (fullColor) {
					var srcRgba = src.rgbaPixels[srcIdx];
					var alpha = (srcRgba >>> 24) & 255;
					if (alpha == 0) {
						atlasPixels.setPixel(ax + px, ay + py, 0x00000000);
						continue;
					}
					if (!src.grayscaleMask[srcIdx]) {
						rgba = srcRgba;
					} else {
						var palIdx = (colors >> (src.pixels[srcIdx] * 8)) & 255;
						rgba = palIdx < 255 ? palette[palIdx] : 0x00000000;
					}
				} else {
					var palIdx = (colors >> (src.pixels[srcIdx] * 8)) & 255;
					rgba = palIdx < 255 ? palette[palIdx] : 0x00000000;
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
