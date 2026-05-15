package game;

import engine.gfx.SpriteId;
import engine.gfx.SpriteRegistry;

/**
 * Named SpriteIds, registered with SpriteRegistry at boot.
 *
 * Many "tile types" share the same sprite cells and only differ in palette
 * (see Screen.render's grayscale-mask path). Names here reflect the actual
 * sprite content on the sheet, not the tile type that happens to use it.
 *
 * Sheet-local coordinates (col, row) for each registration are in trailing
 * comments — easier to cross-reference with art when sprite layouts change.
 */
class SpriteNames {
	// ============================================================
	// TERRAIN SHEET (sprites_terrain.png)
	// ============================================================

	/** 4-quadrant base ground. Palette-shifted into dirt/grass/sand/rock/etc.
	 *  Indices: 0=TL, 1=TR, 2=BL, 3=BR. */
	public static var TERRAIN_BASE:Array<SpriteId>;

	/** Bedrock (StoneTile uses 4× this single sprite). */
	public static var TERRAIN_BEDROCK:SpriteId;                  // (0,1)

	/** Sand stepped-on variant. */
	public static var TERRAIN_SAND_STEPPED:SpriteId;             // (3,1)

	/** Single-cell flower. */
	public static var TERRAIN_FLOWER:SpriteId;                   // (1,1)

	/** Farmland (FarmTile uses 4× this with flips). */
	public static var TERRAIN_FARMLAND:SpriteId;                 // (2,1)

	/** Sapling. */
	public static var TERRAIN_SAPLING:SpriteId;                  // (11,3)

	/** Wheat growth, 4 stages 0..3. */
	public static var TERRAIN_WHEAT:Array<SpriteId>;             // (4..7, 3)

	/** Cactus 4-quadrant. Indices TL,TR,BL,BR. */
	public static var TERRAIN_CACTUS:Array<SpriteId>;            // (8,2)(9,2)(8,3)(9,3)

	/** Ore deposit 4-quadrant. Reused by CloudCactusTile. Indices TL,TR,BL,BR. */
	public static var TERRAIN_ORE:Array<SpriteId>;               // (17,1)(18,1)(17,2)(18,2)

	/** Cloud center 4 corner-variants (CloudTile when not adjacent to fall).
	 *  Indices match the legacy: 0=TL=(17,0), 1=TR=(18,0), 2=BL=(20,0), 3=BR=(19,0). */
	public static var TERRAIN_CLOUD:Array<SpriteId>;

	/** Stairs going down (4 quadrants). */
	public static var TERRAIN_STAIRS_DOWN:Array<SpriteId>;       // (0,2)(1,2)(0,3)(1,3)

	/** Stairs going up (4 quadrants). */
	public static var TERRAIN_STAIRS_UP:Array<SpriteId>;         // (2,2)(3,2)(2,3)(3,3)

	/** Tree sprites — 6 unique cells used in 4-quadrant arrangements. */
	public static var TERRAIN_TREE_LEAVES_FULL:SpriteId;         // (10,1)
	public static var TERRAIN_TREE_LEAVES_TOP:SpriteId;          // (9,0)
	public static var TERRAIN_TREE_LEAVES_BL:SpriteId;           // (9,1)
	public static var TERRAIN_TREE_CANOPY_TR:SpriteId;           // (10,0)
	public static var TERRAIN_TREE_TRUNK:SpriteId;               // (10,2)
	public static var TERRAIN_TREE_TRUNK_BR:SpriteId;            // (10,3)

	// --- Edge tilesets (directional transitions) ---

	/** Grass-shape edges. 3 columns × 3 rows = 9 cells.
	 *  Cols (offset 0/1/2 = sprite cols 11/12/13 = left-edge/center/right-edge).
	 *  Rows (offset 0/1/2 = sprite rows 0/1/2 = top-edge/center/bottom-edge).
	 *  Used by GrassTile, SandTile. Access via edgeGrass*() helpers. */
	public static var TERRAIN_EDGE_GRASS:Array<SpriteId>;

	/** Water-shape edges. 3×3 cells (sprite cols 14/15/16, rows 0/1/2).
	 *  Used by WaterTile, LavaTile, HoleTile. Access via edgeWater*() helpers. */
	public static var TERRAIN_EDGE_WATER:Array<SpriteId>;

	/** Stone-shape edges. 5×3 cells (sprite cols 4..8, rows 0/1/2).
	 *  Used by RockTile, HardRockTile, CloudTile. Access via edgeStone*() helpers. */
	public static var TERRAIN_EDGE_STONE:Array<SpriteId>;

	/** Outer-corner sprites within the stone-edge region. */
	public static var TERRAIN_STONE_CORNER_UL:SpriteId;          // (7,0)
	public static var TERRAIN_STONE_CORNER_DL:SpriteId;          // (7,1)
	public static var TERRAIN_STONE_CORNER_UR:SpriteId;          // (8,0)
	public static var TERRAIN_STONE_CORNER_DR:SpriteId;          // (8,1)

	// ============================================================
	// UI SHEET (sprites_ui.png) — named sprites
	// ============================================================

	/** Swimming water-droplet animation cell (Player). */
	public static var UI_WATER_DROPLET:SpriteId;                 // (5, 7)

	/** Attack-direction indicators (Player). */
	public static var UI_ATTACK_INDICATOR_UPDOWN:SpriteId;       // (6, 7)
	public static var UI_ATTACK_INDICATOR_LEFTRIGHT:SpriteId;    // (7, 7)

	/** Smash-on-impact particle quadrant (SmashParticle). */
	public static var UI_SMASH_PARTICLE:SpriteId;                // (5, 6)

	/** Spark projectile (Spark / AirWizard). */
	public static var UI_SPARK:SpriteId;                         // (8, 7)

	/** HUD heart / slot background. */
	public static var UI_SLOT_HEART:SpriteId;                    // (0, 6)

	/** HUD stamina bar cell. */
	public static var UI_SLOT_STAMINA:SpriteId;                  // (1, 6)

	/** Frame sprites for Font.renderFrame / Engine focus nagger.
	 *  Single base sprite per shape; corner/edge variants are produced via
	 *  the `bits` flip parameter at the call site. */
	public static var UI_FRAME_CORNER:SpriteId;                  // (0, 7)
	public static var UI_FRAME_HORIZ:SpriteId;                   // (1, 7)
	public static var UI_FRAME_VERT:SpriteId;                    // (2, 7)

	/** Font glyph row — one sprite per character index in Font.chars.
	 *  Glyphs are laid out left-to-right in the UI sheet at sheet-local row 24
	 *  (legacy global row 30, offY 6). */
	public static var FONT_GLYPHS:Array<SpriteId>;

	/** Selection-corner marker drawn on the active hotbar slot.
	 *  Pulled from the "sprites" sheet (Screen.colorSheet) at (0,0). */
	public static var COLOR_SELECTION_CORNER:SpriteId;

	// ============================================================
	// Sheet-index cache + raw-tile helpers
	// ============================================================
	// `Item.getSprite()` returns a legacy `col + global_row * 32` tile id.
	// These helpers reconstruct a sheet-local SpriteId without re-running
	// dispatch math at every call site.

	static var terrainIdx:Int;
	static var itemsIdx:Int;
	static var uiIdx:Int;
	static var playerIdx:Int;
	static var monsterIdx:Int;
	static var iconsIdx:Int;
	static var spritesIdx:Int;

	public static inline function rawTile(sheetIdx:Int, legacyTile:Int, offY:Int):SpriteId {
		var col = legacyTile & 31;
		var localRow = (legacyTile >> 5) - offY;
		return SpriteId.packAddress(sheetIdx, col + localRow * 32);
	}

	public static inline function terrainRawTile(t:Int):SpriteId return rawTile(terrainIdx, t, 0);
	public static inline function itemRawTile(t:Int):SpriteId return rawTile(itemsIdx, t, 4);
	public static inline function uiRawTile(t:Int):SpriteId return rawTile(uiIdx, t, 6);
	public static inline function playerRawTile(t:Int):SpriteId return rawTile(playerIdx, t, 14);
	public static inline function monsterRawTile(t:Int):SpriteId return rawTile(monsterIdx, t, 18);
	public static inline function iconRawTile(t:Int):SpriteId return rawTile(iconsIdx, t, 0);
	public static inline function spritesRawTile(t:Int):SpriteId return rawTile(spritesIdx, t, 0);

	// ============================================================
	// Edge-tileset accessors (preserve original tile-id math)
	// ============================================================
	// Original: TL uses (l ? leftCol : centerCol) + (u ? topRow : centerRow) * 32
	//           TR uses (r ? rightCol : centerCol) + (u ? topRow : centerRow) * 32
	//           BL uses (l ? leftCol : centerCol) + (d ? botRow : centerRow) * 32
	//           BR uses (r ? rightCol : centerCol) + (d ? botRow : centerRow) * 32
	// Indexing: flat = colOffset * 3 + rowOffset, where colOffset/rowOffset ∈ {0=edge,1=center,2=opposite-edge}.

	public static inline function edgeGrassTL(l:Bool, u:Bool):SpriteId
		return TERRAIN_EDGE_GRASS[(l ? 0 : 1) * 3 + (u ? 0 : 1)];
	public static inline function edgeGrassTR(r:Bool, u:Bool):SpriteId
		return TERRAIN_EDGE_GRASS[(r ? 2 : 1) * 3 + (u ? 0 : 1)];
	public static inline function edgeGrassBL(l:Bool, d:Bool):SpriteId
		return TERRAIN_EDGE_GRASS[(l ? 0 : 1) * 3 + (d ? 2 : 1)];
	public static inline function edgeGrassBR(r:Bool, d:Bool):SpriteId
		return TERRAIN_EDGE_GRASS[(r ? 2 : 1) * 3 + (d ? 2 : 1)];

	public static inline function edgeWaterTL(l:Bool, u:Bool):SpriteId
		return TERRAIN_EDGE_WATER[(l ? 0 : 1) * 3 + (u ? 0 : 1)];
	public static inline function edgeWaterTR(r:Bool, u:Bool):SpriteId
		return TERRAIN_EDGE_WATER[(r ? 2 : 1) * 3 + (u ? 0 : 1)];
	public static inline function edgeWaterBL(l:Bool, d:Bool):SpriteId
		return TERRAIN_EDGE_WATER[(l ? 0 : 1) * 3 + (d ? 2 : 1)];
	public static inline function edgeWaterBR(r:Bool, d:Bool):SpriteId
		return TERRAIN_EDGE_WATER[(r ? 2 : 1) * 3 + (d ? 2 : 1)];

	// Stone shape uses cols 4..8 (5 cols). Mapping for edge helpers:
	//   colOffset 0 = sprite col 6 (left edge)
	//   colOffset 1 = sprite col 5 (center)
	//   colOffset 2 = sprite col 4 (right edge)
	//   rowOffset 0 = sprite row 2 (top edge)
	//   rowOffset 1 = sprite row 1 (center)
	//   rowOffset 2 = sprite row 0 (bottom edge)
	// Stored as colOffset * 3 + rowOffset, occupying slots 0..8.
	// Outer-corner cells (7,*) and (8,*) live at slots 9..14 but are exposed
	// as TERRAIN_STONE_CORNER_* constants for clarity.

	public static inline function edgeStoneTL(l:Bool, u:Bool):SpriteId
		return TERRAIN_EDGE_STONE[(l ? 0 : 1) * 3 + (u ? 0 : 1)];
	public static inline function edgeStoneTR(r:Bool, u:Bool):SpriteId
		return TERRAIN_EDGE_STONE[(r ? 2 : 1) * 3 + (u ? 0 : 1)];
	public static inline function edgeStoneBL(l:Bool, d:Bool):SpriteId
		return TERRAIN_EDGE_STONE[(l ? 0 : 1) * 3 + (d ? 2 : 1)];
	public static inline function edgeStoneBR(r:Bool, d:Bool):SpriteId
		return TERRAIN_EDGE_STONE[(r ? 2 : 1) * 3 + (d ? 2 : 1)];

	// ============================================================
	// Registration
	// ============================================================

	public static function init(reg:SpriteRegistry):Void {
		// Base 4-quadrant
		TERRAIN_BASE = reg.defineAnim("terrain_base", "terrain",
			[{c:0,r:0},{c:1,r:0},{c:2,r:0},{c:3,r:0}]);

		TERRAIN_BEDROCK      = reg.defineSprite("terrain_bedrock",      "terrain", 0, 1);
		TERRAIN_SAND_STEPPED = reg.defineSprite("terrain_sand_stepped", "terrain", 3, 1);
		TERRAIN_FLOWER       = reg.defineSprite("terrain_flower",       "terrain", 1, 1);
		TERRAIN_FARMLAND     = reg.defineSprite("terrain_farmland",     "terrain", 2, 1);
		TERRAIN_SAPLING      = reg.defineSprite("terrain_sapling",      "terrain", 11, 3);

		TERRAIN_WHEAT = reg.defineAnim("terrain_wheat", "terrain",
			[{c:4,r:3},{c:5,r:3},{c:6,r:3},{c:7,r:3}]);

		TERRAIN_CACTUS = reg.defineAnim("terrain_cactus", "terrain",
			[{c:8,r:2},{c:9,r:2},{c:8,r:3},{c:9,r:3}]);

		TERRAIN_ORE = reg.defineAnim("terrain_ore", "terrain",
			[{c:17,r:1},{c:18,r:1},{c:17,r:2},{c:18,r:2}]);

		// Cloud corners: legacy order TL=17, TR=18, BL=20, BR=19 (not sequential!)
		TERRAIN_CLOUD = reg.defineAnim("terrain_cloud", "terrain",
			[{c:17,r:0},{c:18,r:0},{c:20,r:0},{c:19,r:0}]);

		TERRAIN_STAIRS_DOWN = reg.defineAnim("terrain_stairs_down", "terrain",
			[{c:0,r:2},{c:1,r:2},{c:0,r:3},{c:1,r:3}]);
		TERRAIN_STAIRS_UP = reg.defineAnim("terrain_stairs_up", "terrain",
			[{c:2,r:2},{c:3,r:2},{c:2,r:3},{c:3,r:3}]);

		TERRAIN_TREE_LEAVES_FULL = reg.defineSprite("terrain_tree_leaves_full", "terrain", 10, 1);
		TERRAIN_TREE_LEAVES_TOP  = reg.defineSprite("terrain_tree_leaves_top",  "terrain", 9, 0);
		TERRAIN_TREE_LEAVES_BL   = reg.defineSprite("terrain_tree_leaves_bl",   "terrain", 9, 1);
		TERRAIN_TREE_CANOPY_TR   = reg.defineSprite("terrain_tree_canopy_tr",   "terrain", 10, 0);
		TERRAIN_TREE_TRUNK       = reg.defineSprite("terrain_tree_trunk",       "terrain", 10, 2);
		TERRAIN_TREE_TRUNK_BR    = reg.defineSprite("terrain_tree_trunk_br",    "terrain", 10, 3);

		// Edge tilesets — note iteration order: colOffset outer, rowOffset inner.
		// Grass uses sprite cols 11/12/13 for colOffset 0/1/2; rows 0/1/2 directly.
		TERRAIN_EDGE_GRASS = reg.defineAnim("terrain_edge_grass", "terrain", [
			{c:11,r:0},{c:11,r:1},{c:11,r:2},
			{c:12,r:0},{c:12,r:1},{c:12,r:2},
			{c:13,r:0},{c:13,r:1},{c:13,r:2},
		]);
		// Water uses cols 14/15/16, rows 0/1/2.
		TERRAIN_EDGE_WATER = reg.defineAnim("terrain_edge_water", "terrain", [
			{c:14,r:0},{c:14,r:1},{c:14,r:2},
			{c:15,r:0},{c:15,r:1},{c:15,r:2},
			{c:16,r:0},{c:16,r:1},{c:16,r:2},
		]);
		// Stone: colOffset 0/1/2 maps to sprite cols 6/5/4 (left-edge/center/right-edge).
		//        rowOffset 0/1/2 maps to sprite rows 2/1/0 (top-edge/center/bottom-edge).
		TERRAIN_EDGE_STONE = reg.defineAnim("terrain_edge_stone", "terrain", [
			{c:6,r:2},{c:6,r:1},{c:6,r:0},  // colOffset 0 (left)
			{c:5,r:2},{c:5,r:1},{c:5,r:0},  // colOffset 1 (center)
			{c:4,r:2},{c:4,r:1},{c:4,r:0},  // colOffset 2 (right)
		]);

		TERRAIN_STONE_CORNER_UL = reg.defineSprite("terrain_stone_corner_ul", "terrain", 7, 0);
		TERRAIN_STONE_CORNER_DL = reg.defineSprite("terrain_stone_corner_dl", "terrain", 7, 1);
		TERRAIN_STONE_CORNER_UR = reg.defineSprite("terrain_stone_corner_ur", "terrain", 8, 0);
		TERRAIN_STONE_CORNER_DR = reg.defineSprite("terrain_stone_corner_dr", "terrain", 8, 1);

		// UI sprites
		UI_WATER_DROPLET            = reg.defineSprite("ui_water_droplet",            "ui", 5, 7);
		UI_ATTACK_INDICATOR_UPDOWN  = reg.defineSprite("ui_attack_indicator_updown",  "ui", 6, 7);
		UI_ATTACK_INDICATOR_LEFTRIGHT = reg.defineSprite("ui_attack_indicator_leftright", "ui", 7, 7);
		UI_SMASH_PARTICLE           = reg.defineSprite("ui_smash_particle",           "ui", 5, 6);
		UI_SPARK                    = reg.defineSprite("ui_spark",                    "ui", 8, 7);
		UI_SLOT_HEART               = reg.defineSprite("ui_slot_heart",               "ui", 0, 6);
		UI_SLOT_STAMINA             = reg.defineSprite("ui_slot_stamina",             "ui", 1, 6);
		UI_FRAME_CORNER             = reg.defineSprite("ui_frame_corner",             "ui", 0, 7);
		UI_FRAME_HORIZ              = reg.defineSprite("ui_frame_horiz",              "ui", 1, 7);
		UI_FRAME_VERT               = reg.defineSprite("ui_frame_vert",               "ui", 2, 7);

		// Font glyphs: 67 chars at sheet-local row 24, cols 0..N. Includes spaces;
		// duplicates and unmapped slots are fine — the glyph table is indexed by
		// Font's character map, not by codepoint.
		var glyphFrames = [for (i in 0...67) {c: i, r: 24}];
		FONT_GLYPHS = reg.defineAnim("font_glyphs", "ui", glyphFrames);

		// Colors sheet selection marker
		COLOR_SELECTION_CORNER = reg.defineSprite("color_selection_corner", "sprites", 0, 0);

		// Cache sheet indices for raw-tile helpers.
		terrainIdx = reg.sheetIndexByName.get("terrain");
		itemsIdx   = reg.sheetIndexByName.get("items");
		uiIdx      = reg.sheetIndexByName.get("ui");
		playerIdx  = reg.sheetIndexByName.get("player");
		monsterIdx = reg.sheetIndexByName.get("monster");
		iconsIdx   = reg.sheetIndexByName.get("icons");
		spritesIdx = reg.sheetIndexByName.get("sprites");
	}
}
