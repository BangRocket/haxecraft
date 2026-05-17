// stbtt.hdll — HashLink binding for stb_truetype.
//
// Exposes a tiny API: load a TTF byte buffer, query font-wide metrics,
// rasterize one glyph at a time as 8-bit grayscale into a caller-provided
// buffer. The Haxe-side code is responsible for atlas packing.

#define HL_NAME(n) stbtt_##n
#include <hl.h>

#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_STATIC
#include "stb_truetype.h"

// HL convention for MEM_KIND_FINALIZER: the first slot of the allocated
// struct is a function pointer the GC calls when collecting the object.
typedef void (*hl_finalizer_fn)( void * );

typedef struct {
	hl_finalizer_fn finalize;
	stbtt_fontinfo info;
} hl_stbtt_font;

static void hl_stbtt_finalize( void *p ) {
	// stbtt_fontinfo doesn't allocate beyond the struct; nothing to free.
	// (The Haxe side owns the source byte buffer.)
	(void)p;
}

HL_PRIM hl_stbtt_font *HL_NAME(font_init)( vbyte *data, int size, int font_index ) {
	hl_stbtt_font *f = (hl_stbtt_font*)hl_gc_alloc_finalizer(sizeof(hl_stbtt_font));
	f->finalize = hl_stbtt_finalize;

	int offset = stbtt_GetFontOffsetForIndex((const unsigned char*)data, font_index);
	if( offset < 0 ) return NULL;
	if( !stbtt_InitFont(&f->info, (const unsigned char*)data, offset) ) return NULL;
	return f;
}

HL_PRIM double HL_NAME(scale_for_pixel_height)( hl_stbtt_font *f, double pixel_height ) {
	if( !f ) return 0.0;
	return (double)stbtt_ScaleForPixelHeight(&f->info, (float)pixel_height);
}

HL_PRIM void HL_NAME(get_vmetrics)( hl_stbtt_font *f, int *ascent, int *descent, int *line_gap ) {
	if( !f ) { *ascent = 0; *descent = 0; *line_gap = 0; return; }
	stbtt_GetFontVMetrics(&f->info, ascent, descent, line_gap);
}

HL_PRIM int HL_NAME(find_glyph)( hl_stbtt_font *f, int codepoint ) {
	if( !f ) return 0;
	return stbtt_FindGlyphIndex(&f->info, codepoint);
}

HL_PRIM void HL_NAME(get_glyph_hmetrics)( hl_stbtt_font *f, int glyph, int *advance, int *lsb ) {
	if( !f ) { *advance = 0; *lsb = 0; return; }
	stbtt_GetGlyphHMetrics(&f->info, glyph, advance, lsb);
}

// Returns the glyph's bounding box at the given scale, in pixels (integer).
// The Haxe side uses this to size the bitmap before allocating.
HL_PRIM void HL_NAME(get_glyph_bitmap_box)( hl_stbtt_font *f, int glyph, double scale_x, double scale_y, int *x0, int *y0, int *x1, int *y1 ) {
	if( !f ) { *x0 = 0; *y0 = 0; *x1 = 0; *y1 = 0; return; }
	stbtt_GetGlyphBitmapBox(&f->info, glyph, (float)scale_x, (float)scale_y, x0, y0, x1, y1);
}

// Rasterizes the glyph into out (single-channel, 8-bit) at the given size.
// out must be at least out_w * out_h bytes. The glyph is rendered at the
// top-left corner of the buffer; alignment / atlas packing happens on the
// Haxe side.
HL_PRIM void HL_NAME(make_glyph_bitmap)( hl_stbtt_font *f, vbyte *out, int out_w, int out_h, int stride, double scale_x, double scale_y, int glyph ) {
	if( !f ) return;
	stbtt_MakeGlyphBitmap(&f->info, (unsigned char*)out, out_w, out_h, stride, (float)scale_x, (float)scale_y, glyph);
}

HL_PRIM int HL_NAME(get_kerning)( hl_stbtt_font *f, int glyph1, int glyph2 ) {
	if( !f ) return 0;
	return stbtt_GetGlyphKernAdvance(&f->info, glyph1, glyph2);
}

#define _FONT _ABSTRACT(stbtt_font)

DEFINE_PRIM(_FONT, font_init, _BYTES _I32 _I32);
DEFINE_PRIM(_F64, scale_for_pixel_height, _FONT _F64);
DEFINE_PRIM(_VOID, get_vmetrics, _FONT _REF(_I32) _REF(_I32) _REF(_I32));
DEFINE_PRIM(_I32, find_glyph, _FONT _I32);
DEFINE_PRIM(_VOID, get_glyph_hmetrics, _FONT _I32 _REF(_I32) _REF(_I32));
DEFINE_PRIM(_VOID, get_glyph_bitmap_box, _FONT _I32 _F64 _F64 _REF(_I32) _REF(_I32) _REF(_I32) _REF(_I32));
DEFINE_PRIM(_VOID, make_glyph_bitmap, _FONT _BYTES _I32 _I32 _I32 _F64 _F64 _I32);
DEFINE_PRIM(_I32, get_kerning, _FONT _I32 _I32);
