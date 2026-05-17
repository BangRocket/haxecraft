package engine.gfx;

class SpriteRegistry {
	public var atlases:Array<SpriteAtlas> = [];
	public var sheets:Array<AtlasSheet> = [];
	public var sheetIndexByName:Map<String, Int> = new Map();
	var byName:Map<String, SpriteId> = new Map();
	var animByName:Map<String, Array<SpriteId>> = new Map();
	var compositeByName:Map<String, CompositeSprite> = new Map();
	public var palettes:PaletteRegistry = new PaletteRegistry();

	public function new() {}

	public function registerAtlas(a:SpriteAtlas):Void {
		atlases.push(a);
		for (s in a.sheets) {
			var idx = sheets.length;
			sheets.push(s);
			sheetIndexByName.set(s.name, idx);
		}
	}

	public function defineSprite(name:String, sheetName:String, col:Int, row:Int):SpriteId {
		var idx = sheetIndexByName.get(sheetName);
		if (idx == null) throw 'Unknown sheet: $sheetName';
		var sheet = sheets[idx];
		var spriteIdx = col + row * sheet.cols;
		var id = SpriteId.packAddress(idx, spriteIdx);
		byName.set(name, id);
		return id;
	}

	public inline function rebindSprite(name:String, id:SpriteId):Void {
		byName.set(name, id);
	}

	public inline function definePalette(name:String, colors:Int):Int {
		return palettes.define(name, colors);
	}

	public function registerEngineSheet(name:String, sheet:SpriteSheet, spriteW:Int = 8, spriteH:Int = 8):Int {
		var atlas = new SpriteAtlas(name, sheet);
		var cols = Std.int(sheet.width / spriteW);
		var rows = Std.int(sheet.height / spriteH);
		atlas.addSheet(new AtlasSheet(name, atlas, 0, 0, spriteW, spriteH, cols, rows));
		registerAtlas(atlas);
		return sheetIndexByName.get(name);
	}

	public function defineAnim(name:String, sheetName:String, frames:Array<{c:Int, r:Int}>):Array<SpriteId> {
		var arr = [];
		for (i in 0...frames.length) {
			var f = frames[i];
			arr.push(defineSprite('$name#$i', sheetName, f.c, f.r));
		}
		animByName.set(name, arr);
		return arr;
	}

	public function defineComposite(name:String, c:CompositeSprite):Void {
		compositeByName.set(name, c);
	}

	public inline function get(name:String):SpriteId {
		var id = byName.get(name);
		if (id == null) throw 'Unknown sprite: $name';
		return id;
	}

	public inline function getAnim(name:String):Array<SpriteId> {
		var a = animByName.get(name);
		if (a == null) throw 'Unknown anim: $name';
		return a;
	}

	public inline function getComposite(name:String):CompositeSprite {
		var c = compositeByName.get(name);
		if (c == null) throw 'Unknown composite: $name';
		return c;
	}

	public inline function spriteCount():Int return Lambda.count(byName);
	public inline function animCount():Int return Lambda.count(animByName);
	public inline function compositeCount():Int return Lambda.count(compositeByName);

	public inline function lookup(id:SpriteId):{sheet:AtlasSheet, col:Int, row:Int} {
		var s = sheets[id.getSheetIndex()];
		var i = id.getSpriteIndex();
		return {sheet: s, col: i % s.cols, row: Std.int(i / s.cols)};
	}
}
