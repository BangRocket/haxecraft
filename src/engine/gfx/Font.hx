package engine.gfx;

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
				screen.render(x + i * 8, y, ix + 30 * 32, col, 0);
			}
		}
	}

	public static function renderFrame(screen:Screen, title:String, x0:Int, y0:Int, x1:Int, y1:Int) {
		for (y in y0...(y1 + 1)) {
			for (x in x0...(x1 + 1)) {
				if (x == x0 && y == y0)
					screen.render(x * 8, y * 8, 0 + 13 * 32, 0);
				else if (x == x1 && y == y0)
					screen.render(x * 8, y * 8, 0 + 13 * 32, 1);
				else if (x == x0 && y == y1)
					screen.render(x * 8, y * 8, 0 + 13 * 32, 2);
				else if (x == x1 && y == y1)
					screen.render(x * 8, y * 8, 0 + 13 * 32, 3);
				else if (y == y0)
					screen.render(x * 8, y * 8, 1 + 13 * 32, 0);
				else if (y == y1)
					screen.render(x * 8, y * 8, 1 + 13 * 32, 2);
				else if (x == x0)
					screen.render(x * 8, y * 8, 2 + 13 * 32, 0);
				else if (x == x1)
					screen.render(x * 8, y * 8, 2 + 13 * 32, 1);
				else
					screen.render(x * 8, y * 8, 2 + 13 * 32, 1);
			}
		}

		draw(title, screen, x0 * 8 + 8, y0 * 8, Color.get(5, 5, 5, 550));
	}
}
