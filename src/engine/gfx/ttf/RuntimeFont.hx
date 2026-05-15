package engine.gfx.ttf;

import h2d.Font;
import h2d.Font.FontChar;
import h2d.Tile;
import h3d.mat.Texture;
import haxe.io.Bytes;
import hxd.Pixels;

/**
 * Rasterize a TTF at runtime via stb_truetype, pack the glyphs into a
 * texture atlas, and hand back an `h2d.Font` ready for `h2d.Text`.
 *
 * Single-page atlas, naive shelf packer — enough for a Latin-1-ish charset
 * at typical UI sizes. Bump `atlasSize` for larger fonts or extended sets.
 */
@:access(h2d.Font)
class RuntimeFont {
	// Printable ASCII (32..126).
	public static var DEFAULT_CHARS = [for (c in 32...127) c];

	/**
	 * Set true to threshold the rasterized alpha — any pixel ≥ 128 becomes
	 * fully opaque, anything below becomes fully transparent. Required for
	 * pixel-art fonts (Mago, Press Start, etc.) where stb_truetype's default
	 * anti-aliased output softens what should be hard 1-bit edges.
	 *
	 * Set false for proportional / smooth fonts where AA is desirable.
	 */
	public static var pixelArtMode = true;

	public static function build(ttfBytes:Bytes, pixelHeight:Int, ?charset:Array<Int>, atlasSize:Int = 256):Font {
		if (charset == null) charset = DEFAULT_CHARS;

		var stb = StbTrueType.font_init(ttfBytes.getData(), ttfBytes.length, 0);
		if (stb == null) throw "stb_truetype: failed to parse TTF";

		var scale = StbTrueType.scale_for_pixel_height(stb, pixelHeight);

		var ascent = 0, descent = 0, lineGap = 0;
		StbTrueType.get_vmetrics(stb, ascent, descent, lineGap);
		var ascentPx  = Math.round(ascent  * scale);
		var descentPx = Math.round(descent * scale);
		var lineGapPx = Math.round(lineGap * scale);

		var pixels = Pixels.alloc(atlasSize, atlasSize, RGBA);
		// Transparent black background — Pixels.alloc already zeroes.

		var font = new Font("ttf-" + pixelHeight, pixelHeight);
		font.lineHeight = ascentPx - descentPx + lineGapPx;
		font.baseLine = ascentPx;

		var cursorX = 1, cursorY = 1;
		var rowH = 0;
		var padding = 1;

		// First pass: rasterize each glyph into the pixel atlas, recording
		// where it landed so we can build sub-tiles after texture upload.
		var rects:Map<Int, {x:Int, y:Int, w:Int, h:Int, dx:Int, dy:Int, advance:Int}> = new Map();

		for (cp in charset) {
			var gi = StbTrueType.find_glyph(stb, cp);
			if (gi == 0) continue;

			var advance = 0, lsb = 0;
			StbTrueType.get_glyph_hmetrics(stb, gi, advance, lsb);
			var advancePx = Math.round(advance * scale);

			var x0 = 0, y0 = 0, x1 = 0, y1 = 0;
			StbTrueType.get_glyph_bitmap_box(stb, gi, scale, scale, x0, y0, x1, y1);
			var gw = x1 - x0;
			var gh = y1 - y0;

			if (gw <= 0 || gh <= 0) {
				// Whitespace / zero-area — record empty rect so we still emit a FontChar.
				rects.set(cp, { x: 0, y: 0, w: 0, h: 0, dx: 0, dy: 0, advance: advancePx });
				continue;
			}

			if (cursorX + gw + padding >= atlasSize) {
				cursorX = 1;
				cursorY += rowH + padding;
				rowH = 0;
			}
			if (cursorY + gh + padding >= atlasSize) {
				throw 'RuntimeFont atlas overflow at codepoint $cp; bump atlasSize.';
			}

			// Rasterize into a single-channel buffer, then splatter into the
			// RGBA atlas at (cursorX, cursorY) with white RGB and alpha = stb output.
			var glyphBytes = Bytes.alloc(gw * gh);
			StbTrueType.make_glyph_bitmap(stb, glyphBytes.getData(), gw, gh, gw, scale, scale, gi);
			for (gy in 0...gh) {
				for (gx in 0...gw) {
					var alpha = glyphBytes.get(gy * gw + gx);
					if (pixelArtMode) alpha = (alpha >= 128) ? 0xFF : 0x00;
					if (alpha == 0) continue;
					var px = cursorX + gx;
					var py = cursorY + gy;
					var off = (py * atlasSize + px) * 4;
					pixels.bytes.set(off,     0xFF);
					pixels.bytes.set(off + 1, 0xFF);
					pixels.bytes.set(off + 2, 0xFF);
					pixels.bytes.set(off + 3, alpha);
				}
			}

			rects.set(cp, {
				x: cursorX, y: cursorY, w: gw, h: gh,
				dx: x0, dy: ascentPx + y0,
				advance: advancePx
			});

			cursorX += gw + padding;
			if (gh > rowH) rowH = gh;
		}

		// Upload the atlas to a GPU texture and back-fill glyph tiles.
		var tex = new Texture(atlasSize, atlasSize, [Dynamic], h3d.mat.Texture.nativeFormat);
		tex.uploadPixels(pixels);
		tex.filter = Nearest;
		var atlasTile = Tile.fromTexture(tex);
		font.tile = atlasTile;

		for (cp in charset) {
			var r = rects.get(cp);
			if (r == null) continue;
			var sub = (r.w > 0 && r.h > 0)
				? atlasTile.sub(r.x, r.y, r.w, r.h, r.dx, r.dy)
				: atlasTile.sub(0, 0, 0, 0);
			var fc = new FontChar(sub, r.advance);
			font.glyphs.set(cp, fc);
		}

		// Set a sensible default glyph (use '?' if present, else first char).
		var fallback = font.glyphs.get('?'.code);
		if (fallback == null) {
			for (c in font.glyphs) { fallback = c; break; }
		}
		if (fallback != null) {
			font.defaultChar = fallback;
		}

		return font;
	}
}
