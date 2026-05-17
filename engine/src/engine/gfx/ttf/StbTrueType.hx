package engine.gfx.ttf;

import haxe.io.Bytes;

/**
 * Low-level Haxe binding to the stbtt.hdll wrapper around stb_truetype.
 * Only the calls we use; expand if you need kerning subtables, etc.
 */
@:hlNative("stbtt", "")
class StbTrueType {
	public static function font_init(data:hl.Bytes, size:Int, fontIndex:Int):StbttFont return null;
	public static function scale_for_pixel_height(font:StbttFont, pixelHeight:Float):Float return 0.0;
	public static function get_vmetrics(font:StbttFont, ascent:hl.Ref<Int>, descent:hl.Ref<Int>, lineGap:hl.Ref<Int>):Void {}
	public static function find_glyph(font:StbttFont, codepoint:Int):Int return 0;
	public static function get_glyph_hmetrics(font:StbttFont, glyph:Int, advance:hl.Ref<Int>, lsb:hl.Ref<Int>):Void {}
	public static function get_glyph_bitmap_box(font:StbttFont, glyph:Int, scaleX:Float, scaleY:Float, x0:hl.Ref<Int>, y0:hl.Ref<Int>, x1:hl.Ref<Int>, y1:hl.Ref<Int>):Void {}
	public static function make_glyph_bitmap(font:StbttFont, out:hl.Bytes, w:Int, h:Int, stride:Int, scaleX:Float, scaleY:Float, glyph:Int):Void {}
	public static function get_kerning(font:StbttFont, glyph1:Int, glyph2:Int):Int return 0;
}

abstract StbttFont(hl.Abstract<"stbtt_font">) {}
