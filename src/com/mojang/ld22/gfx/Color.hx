package com.mojang.ld22.gfx;

class Color {
	public static function get(a:Int, ?b:Int, ?c:Int, ?d:Int):Int {
		if (b == null) {
			if (a < 0) return 255;
			var r = Std.int(a / 100) % 10;
			var g = Std.int(a / 10) % 10;
			var b = a % 10;
			return r * 36 + g * 6 + b;
		}
		return (get(d) << 24) | (get(c) << 16) | (get(b) << 8) | (get(a));
	}
}
