package engine.gfx;

class Color {
	public static inline function channel(a:Int):Int {
		if (a < 0) return 255;
		var r = Std.int(a / 100) % 10;
		var g = Std.int(a / 10) % 10;
		var b = a % 10;
		return r * 36 + g * 6 + b;
	}

	public static inline function get(a:Int, ?b:Int, ?c:Int, ?d:Int):Int {
		return b == null
			? channel(a)
			: (channel(d) << 24) | (channel(c) << 16) | (channel(b) << 8) | channel(a);
	}
}
