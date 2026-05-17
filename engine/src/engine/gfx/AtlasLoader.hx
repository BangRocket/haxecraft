package engine.gfx;

import engine.gfx.Color;
import engine.gfx.CompositeSprite.CompositePart;
import haxe.Json;

class AtlasLoader {
	public static function loadManifest(jsonPath:String, registry:SpriteRegistry):Void {
		var raw = hxd.Res.load(jsonPath).toText();
		var data:Dynamic = Json.parse(raw);

		var atlasesData:Array<Dynamic> = data.atlases;
		for (ad in atlasesData) {
			var img = hxd.Res.load(ad.image).toImage().getPixels();
			var sheet = new SpriteSheet(img);
			var atlas = new SpriteAtlas(ad.name, sheet);
			var sheetsData:Array<Dynamic> = ad.sheets;
			for (sd in sheetsData) {
				atlas.addSheet(new AtlasSheet(
					sd.name, atlas, sd.x, sd.y,
					sd.spriteW, sd.spriteH, sd.cols, sd.rows
				));
			}
			registry.registerAtlas(atlas);
		}

		if (data.palettes != null) {
			var pals:Dynamic = data.palettes;
			for (name in Reflect.fields(pals)) {
				var arr:Array<Int> = Reflect.field(pals, name);
				var packed = Color.get(arr[0], arr[1], arr[2], arr[3]);
				registry.definePalette(name, packed);
			}
		}

		var spritesData:Dynamic = data.sprites;
		if (spritesData != null) {
			for (name in Reflect.fields(spritesData)) {
				var entry:Dynamic = Reflect.field(spritesData, name);
				if (entry.frames != null) {
					var frames:Array<Array<Int>> = entry.frames;
					var ids = registry.defineAnim(name, entry.sheet,
						[for (f in frames) {c: f[0], r: f[1]}]);
					if (entry.color != null) {
						var palIdx = registry.palettes.indexOf(entry.color);
						for (i in 0...ids.length) {
							registry.rebindSprite('$name#$i', ids[i].withPalette(palIdx));
						}
					}
				} else {
					var id = registry.defineSprite(name, entry.sheet, entry.col, entry.row);
					if (entry.color != null) {
						var palIdx = registry.palettes.indexOf(entry.color);
						registry.rebindSprite(name, id.withPalette(palIdx));
					}
				}
			}
		}

		if (data.composites != null) {
			var comps:Dynamic = data.composites;
			for (name in Reflect.fields(comps)) {
				var c:Dynamic = Reflect.field(comps, name);
				var partsData:Array<Dynamic> = c.parts;
				var parts = [for (p in partsData)
					new CompositePart(registry.get(p.sprite), p.dx, p.dy, p.flip != null ? p.flip : 0)];
				registry.defineComposite(name, new CompositeSprite(
					name, c.w, c.h,
					c.anchorX != null ? c.anchorX : 0,
					c.anchorY != null ? c.anchorY : 0,
					parts
				));
			}
		}
	}
}
