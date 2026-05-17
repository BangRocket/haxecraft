package engine.gfx;

class PaletteRegistry {
	public var entries:Array<Int> = [];
	var indexByName:Map<String, Int> = new Map();

	public function new() {}

	public function define(name:String, colors:Int):Int {
		var existing = indexByName.get(name);
		if (existing != null) {
			entries[existing] = colors;
			return existing;
		}
		if (entries.length >= 512) throw 'PaletteRegistry full (512 entries max): cannot add $name';
		var idx = entries.length;
		entries.push(colors);
		indexByName.set(name, idx);
		return idx;
	}

	public inline function indexOf(name:String):Int {
		var i = indexByName.get(name);
		if (i == null) throw 'Unknown palette: $name';
		return i;
	}

	public inline function get(index:Int):Int return entries[index];
	public inline function count():Int return entries.length;
}
