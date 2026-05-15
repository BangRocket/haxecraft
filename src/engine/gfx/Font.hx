package engine.gfx;

import game.SpriteNames;

class Font {
	static var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ      0123456789.,!?'\"-+=/\\%()<>:;     ";

	static var charMap:haxe.ds.IntMap<Int> = {
		var m = new haxe.ds.IntMap<Int>();
		for (i in 0...chars.length) {
			var code = chars.charCodeAt(i);
			if (code != null && code != " ".code && !m.exists(code)) m.set(code, i);
		}
		m;
	};

	static inline var UPPER_DELTA = "a".code - "A".code;

	public static function draw(msg:String, screen:Screen, x:Int, y:Int, col:Int) {
		for (i in 0...msg.length) {
			var code = msg.charCodeAt(i);
			if (code == null) continue;
			if (code >= "a".code && code <= "z".code) code -= UPPER_DELTA;
			var ix = charMap.get(code);
			if (ix != null) {
				screen.renderSprite(x + i * 8, y, SpriteNames.FONT_GLYPHS[ix], col, 0);
			}
		}
	}

	public static function renderFrame(screen:Screen, title:String, x0:Int, y0:Int, x1:Int, y1:Int) {
		for (y in y0...(y1 + 1)) {
			for (x in x0...(x1 + 1)) {
				if (x == x0 && y == y0)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 0);
				else if (x == x1 && y == y0)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 1);
				else if (x == x0 && y == y1)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 2);
				else if (x == x1 && y == y1)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 3);
				else if (y == y0)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_HORIZ, Color.get(-1, 1, 5, 445), 0);
				else if (y == y1)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_HORIZ, Color.get(-1, 1, 5, 445), 2);
				else if (x == x0)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_VERT, Color.get(-1, 1, 5, 445), 0);
				else if (x == x1)
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_VERT, Color.get(5, 5, 5, 5), 1);
				else
					screen.renderSprite(x * 8, y * 8, SpriteNames.UI_FRAME_VERT, Color.get(5, 5, 5, 5), 1);
			}
		}

		draw(title, screen, x0 * 8 + 8, y0 * 8, Color.get(5, 5, 5, 550));
	}
}
