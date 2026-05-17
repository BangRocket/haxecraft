package engine.gfx;

/**
 * TTF text layer for HUD chrome. Sits ON TOP of the sprite tile group and
 * primitives, so labels render after everything else. Pools `h2d.Text`
 * instances frame-to-frame to avoid GC churn.
 *
 * Draw model is immediate-mode: call `beginFrame()`, then `draw()` per
 * label, then `endFrame()` to hide any leftover pool entries from the
 * previous frame.
 *
 * Defaults to `hxd.res.DefaultFont.get()` until `setFont(...)` is called
 * with a custom font (typically a TTF or BMFont loaded from `res/`).
 */
class ChromeText {
	public static inline var BRIGHT = 0xFFFFFF;
	public static inline var DIM    = 0x888888;
	public static inline var ORANGE = 0xD67000;
	public static inline var ORANGE_BRIGHT = 0xFFB044;
	public static inline var RED    = 0xE04050;
	public static inline var BLUE   = 0x4080E0;

	static var font:h2d.Font;
	static var largeFont:h2d.Font;
	static var container:h2d.Object;
	static var pool:Array<h2d.Text> = [];
	static var largePool:Array<h2d.Text> = [];
	static var active:Int = 0;
	static var activeLarge:Int = 0;
	static var measurer:h2d.Text;
	static var largeMeasurer:h2d.Text;

	public static function init(parent:h2d.Object):Void {
		container = new h2d.Object(parent);
		font = hxd.res.DefaultFont.get();
		largeFont = font;
	}

	public static function setFont(f:h2d.Font):Void {
		font = f;
		// Existing pool members hold a reference to the previous font; force
		// a re-bind on next draw by clearing the pool.
		for (t in pool) t.remove();
		pool = [];
		active = 0;
		measurer = null;
	}

	public static function setLargeFont(f:h2d.Font):Void {
		largeFont = f;
		for (t in largePool) t.remove();
		largePool = [];
		activeLarge = 0;
		largeMeasurer = null;
	}

	public static function setScale(sx:Float, sy:Float):Void {
		if (container == null) return;
		container.scaleX = sx;
		container.scaleY = sy;
	}

	public static function beginFrame():Void {
		active = 0;
		activeLarge = 0;
	}

	public static function draw(msg:String, x:Float, y:Float, color:Int):Void {
		drawWith(font, pool, msg, x, y, color, function(idx) { active = idx; }, active);
	}

	public static function drawLarge(msg:String, x:Float, y:Float, color:Int):Void {
		drawWith(largeFont, largePool, msg, x, y, color, function(idx) { activeLarge = idx; }, activeLarge);
	}

	static function drawWith(f:h2d.Font, p:Array<h2d.Text>, msg:String, x:Float, y:Float, color:Int, setIdx:Int->Void, idx:Int):Void {
		if (f == null || container == null) return;
		var t:h2d.Text;
		if (idx < p.length) {
			t = p[idx];
			t.visible = true;
		} else {
			t = new h2d.Text(f, container);
			// Pixel-art font atlas is rendered with `Nearest` filter; smoothing
			// the Text would force bilinear sampling and re-blur the glyphs.
			t.smooth = false;
			p.push(t);
		}
		if (t.font != f) t.font = f;
		t.text = msg;
		t.x = x;
		t.y = y;
		t.textColor = color;
		setIdx(idx + 1);
	}

	public static function measure(msg:String):Int {
		if (font == null || container == null) return 0;
		if (measurer == null) {
			measurer = new h2d.Text(font, container);
			measurer.smooth = false;
			measurer.visible = false;
		}
		measurer.text = msg;
		return Std.int(measurer.textWidth);
	}

	public static function measureLarge(msg:String):Int {
		if (largeFont == null || container == null) return 0;
		if (largeMeasurer == null) {
			largeMeasurer = new h2d.Text(largeFont, container);
			largeMeasurer.smooth = false;
			largeMeasurer.visible = false;
		}
		largeMeasurer.text = msg;
		return Std.int(largeMeasurer.textWidth);
	}

	public static function endFrame():Void {
		for (i in active...pool.length) pool[i].visible = false;
		for (i in activeLarge...largePool.length) largePool[i].visible = false;
	}
}
