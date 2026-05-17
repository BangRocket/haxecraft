package engine.gfx;

class SpriteAtlas {
	public var name:String;
	public var sheet:SpriteSheet;
	public var sheets:Array<AtlasSheet>;

	public function new(name:String, sheet:SpriteSheet) {
		this.name = name;
		this.sheet = sheet;
		this.sheets = [];
	}

	public function addSheet(s:AtlasSheet):Void {
		sheets.push(s);
	}
}
