package engine.gfx;

abstract SpriteId(Int) from Int to Int {
	public inline function new(v:Int) this = v;

	static inline var SPRITE_MASK = 0xFFFF;
	static inline var SHEET_MASK = 0x3F;
	static inline var COLOR_MASK = 0x1FF;

	static inline var SHEET_SHIFT = 16;
	static inline var COLOR_SHIFT = 22;
	static inline var MODE_MASK_BIT = 0x80000000;

	public static inline function packAddress(sheetIndex:Int, spriteIndex:Int):SpriteId {
		return new SpriteId(((sheetIndex & SHEET_MASK) << SHEET_SHIFT) | (spriteIndex & SPRITE_MASK));
	}

	public inline function withPalette(colorIndex:Int):SpriteId {
		var cleared = (this : Int) & ~(MODE_MASK_BIT | (COLOR_MASK << COLOR_SHIFT));
		return new SpriteId(cleared | MODE_MASK_BIT | ((colorIndex & COLOR_MASK) << COLOR_SHIFT));
	}

	public inline function withRgba():SpriteId {
		var cleared = (this : Int) & ~(MODE_MASK_BIT | (COLOR_MASK << COLOR_SHIFT));
		return new SpriteId(cleared);
	}

	public inline function isPalette():Bool return ((this : Int) & MODE_MASK_BIT) != 0;
	public inline function getColorIndex():Int return ((this : Int) >>> COLOR_SHIFT) & COLOR_MASK;
	public inline function getSheetIndex():Int return ((this : Int) >>> SHEET_SHIFT) & SHEET_MASK;
	public inline function getSpriteIndex():Int return (this : Int) & SPRITE_MASK;

	public static inline final NONE:SpriteId = new SpriteId(-1);
	public inline function isNone():Bool return (this : Int) == -1;
}
