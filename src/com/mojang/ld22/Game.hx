package com.mojang.ld22;

import com.mojang.ld22.entity.Player;
import com.mojang.ld22.crafting.Crafting;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Font;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.gfx.SpriteSheet;
import com.mojang.ld22.level.Level;
import com.mojang.ld22.level.tile.Tile;
import com.mojang.ld22.screen.DeadMenu;
import com.mojang.ld22.screen.LevelTransitionMenu;
import com.mojang.ld22.screen.Menu;
import com.mojang.ld22.screen.TitleMenu;
import com.mojang.ld22.screen.WonMenu;
import h2d.Bitmap;
import h2d.Tile as H2dTile;
import h3d.mat.Texture;
import h3d.mat.Data.TextureFlags;
import hxd.Pixels;
import hxd.PixelFormat;
import hxd.Window;

class Game extends hxd.App {
	public static inline var NAME = "Minicraft";
	public static inline var HEIGHT = 240;
	public static inline var WIDTH = 320;
	static inline var SCALE = 2;

	var bitmap:Bitmap;
	var frameTexture:Texture;
	var framePixels:Pixels;
	var screen:Screen;
	var lightScreen:Screen;
	var input = new InputHandler();
	var colors:Array<Int> = [];
	var tickCount = 0;
	var level:Level;
	var levels:Array<Level> = [];
	var currentLevel = 3;
	var playerDeadTime = 0;
	var pendingLevelChange = 0;
	var wonTimer = 0;
	var accumulator = 0.0;

	public var gameTime = 0;
	public var player:Player;
	public var menu:Menu;
	public var hasWon = false;

	public static function main() {
		hxd.Res.initLocal();
		new Game();
	}

	override function init() {
		var window = Window.getInstance();
		window.title = NAME;
		window.resize(WIDTH * SCALE, HEIGHT * SCALE);

		initPalette();
		var icons = hxd.Res.load("icons.png").toImage().getPixels();
		screen = new Screen(WIDTH, HEIGHT, new SpriteSheet(icons));
		lightScreen = new Screen(WIDTH, HEIGHT, new SpriteSheet(icons));
		framePixels = Pixels.alloc(WIDTH, HEIGHT, PixelFormat.RGBA);
		frameTexture = new Texture(WIDTH, HEIGHT, [TextureFlags.Dynamic], h3d.mat.Texture.nativeFormat);
		bitmap = new Bitmap(H2dTile.fromTexture(frameTexture), s2d);
		bitmap.scale(SCALE);
		bitmap.x = 0;
		bitmap.y = 0;

		Crafting.init();
		resetGame();
		setMenu(new TitleMenu());
	}

	function initPalette() {
		var pp = 0;
		for (r in 0...6) {
			for (g in 0...6) {
				for (b in 0...6) {
					var rr = Std.int(r * 255 / 5);
					var gg = Std.int(g * 255 / 5);
					var bb = Std.int(b * 255 / 5);
					var mid = Std.int((rr * 30 + gg * 59 + bb * 11) / 100);

					var r1 = Std.int(((rr + mid) / 2) * 230 / 255 + 10);
					var g1 = Std.int(((gg + mid) / 2) * 230 / 255 + 10);
					var b1 = Std.int(((bb + mid) / 2) * 230 / 255 + 10);
					colors[pp++] = 0xff000000 | (r1 << 16) | (g1 << 8) | b1;
				}
			}
		}
	}

	public function setMenu(menu:Menu) {
		this.menu = menu;
		if (menu != null) menu.init(this, input);
	}

	public function resetGame() {
		playerDeadTime = 0;
		wonTimer = 0;
		gameTime = 0;
		hasWon = false;

		levels = [];
		currentLevel = 3;

		levels[4] = new Level(128, 128, 1, null);
		levels[3] = new Level(128, 128, 0, levels[4]);
		levels[2] = new Level(128, 128, -1, levels[3]);
		levels[1] = new Level(128, 128, -2, levels[2]);
		levels[0] = new Level(128, 128, -3, levels[1]);

		level = levels[currentLevel];
		player = new Player(this, input);
		player.findStartPos(level);
		level.add(player);

		for (i in 0...5) {
			levels[i].trySpawn(5000);
		}
	}

	override function update(dt:Float) {
		accumulator += dt * 60;
		while (accumulator >= 1) {
			tick();
			accumulator--;
		}
		renderGame();
	}

	public function tick() {
		tickCount++;
		if (!hxd.Window.getInstance().isFocused) {
			input.releaseAll();
			return;
		}

		input.updateKeys();
		if (!player.removed && !hasWon) gameTime++;

		input.tick();
		if (menu != null) {
			menu.tick();
		} else {
			if (player.removed) {
				playerDeadTime++;
				if (playerDeadTime > 60) {
					setMenu(new DeadMenu());
				}
			} else if (pendingLevelChange != 0) {
				setMenu(new LevelTransitionMenu(pendingLevelChange));
				pendingLevelChange = 0;
			}
			if (wonTimer > 0) {
				if (--wonTimer == 0) {
					setMenu(new WonMenu());
				}
			}
			level.tick();
			Tile.tickCount++;
		}
	}

	public function changeLevel(dir:Int) {
		level.remove(player);
		currentLevel += dir;
		level = levels[currentLevel];
		player.x = (player.x >> 4) * 16 + 8;
		player.y = (player.y >> 4) * 16 + 8;
		level.add(player);
	}

	function renderGame() {
		var xScroll = player.x - Std.int(screen.w / 2);
		var yScroll = player.y - Std.int((screen.h - 8) / 2);
		if (xScroll < 16) xScroll = 16;
		if (yScroll < 16) yScroll = 16;
		if (xScroll > level.w * 16 - screen.w - 16) xScroll = level.w * 16 - screen.w - 16;
		if (yScroll > level.h * 16 - screen.h - 16) yScroll = level.h * 16 - screen.h - 16;
		if (currentLevel > 3) {
			var col = Color.get(20, 20, 121, 121);
			var rows = Std.int((screen.h + 15) / 8) + 1;
			var cols = Std.int((screen.w + 15) / 8) + 1;
			for (y in 0...rows) {
				for (x in 0...cols) {
					screen.render(x * 8 - ((Std.int(xScroll / 4)) & 7), y * 8 - ((Std.int(yScroll / 4)) & 7), 0, col, 0);
				}
			}
		}

		level.renderBackground(screen, xScroll, yScroll);
		level.renderSprites(screen, xScroll, yScroll);

		if (currentLevel < 3) {
			lightScreen.clear(0);
			level.renderLight(lightScreen, xScroll, yScroll);
			screen.overlay(lightScreen, xScroll, yScroll);
		}

		renderGui();
		if (!hxd.Window.getInstance().isFocused) renderFocusNagger();
		copyFrame();
	}

	function renderGui() {
		for (y in 0...2) {
			for (x in 0...20) {
				screen.render(x * 8, screen.h - 16 + y * 8, 0 + 12 * 32, Color.get(0, 0, 0, 0), 0);
			}
		}

		for (i in 0...10) {
			if (i < player.health)
				screen.render(i * 8, screen.h - 16, 0 + 12 * 32, Color.get(0, 200, 500, 533), 0);
			else
				screen.render(i * 8, screen.h - 16, 0 + 12 * 32, Color.get(0, 100, 0, 0), 0);

			if (player.staminaRechargeDelay > 0) {
				if (Std.int(player.staminaRechargeDelay / 4) % 2 == 0)
					screen.render(i * 8, screen.h - 8, 1 + 12 * 32, Color.get(0, 555, 0, 0), 0);
				else
					screen.render(i * 8, screen.h - 8, 1 + 12 * 32, Color.get(0, 110, 0, 0), 0);
			} else if (i < player.stamina) {
				screen.render(i * 8, screen.h - 8, 1 + 12 * 32, Color.get(0, 220, 550, 553), 0);
			} else {
				screen.render(i * 8, screen.h - 8, 1 + 12 * 32, Color.get(0, 110, 0, 0), 0);
			}
		}
		if (player.activeItem != null) {
			player.activeItem.renderInventory(screen, 10 * 8, screen.h - 16);
		}

		if (menu != null) {
			menu.render(screen);
		}
	}

	function renderFocusNagger() {
		var msg = "Click to focus!";
		var xx = Std.int((WIDTH - msg.length * 8) / 2);
		var yy = Std.int((HEIGHT - 8) / 2);
		var w = msg.length;
		var h = 1;

		screen.render(xx - 8, yy - 8, 0 + 13 * 32, Color.get(-1, 1, 5, 445), 0);
		screen.render(xx + w * 8, yy - 8, 0 + 13 * 32, Color.get(-1, 1, 5, 445), 1);
		screen.render(xx - 8, yy + 8, 0 + 13 * 32, Color.get(-1, 1, 5, 445), 2);
		screen.render(xx + w * 8, yy + 8, 0 + 13 * 32, Color.get(-1, 1, 5, 445), 3);
		for (x in 0...w) {
			screen.render(xx + x * 8, yy - 8, 1 + 13 * 32, Color.get(-1, 1, 5, 445), 0);
			screen.render(xx + x * 8, yy + 8, 1 + 13 * 32, Color.get(-1, 1, 5, 445), 2);
		}
		for (y in 0...h) {
			screen.render(xx - 8, yy + y * 8, 2 + 13 * 32, Color.get(-1, 1, 5, 445), 0);
			screen.render(xx + w * 8, yy + y * 8, 2 + 13 * 32, Color.get(-1, 1, 5, 445), 1);
		}

		if (Std.int(tickCount / 20) % 2 == 0)
			Font.draw(msg, screen, xx, yy, Color.get(5, 333, 333, 333));
		else
			Font.draw(msg, screen, xx, yy, Color.get(5, 555, 555, 555));
	}

	function copyFrame() {
		for (y in 0...screen.h) {
			for (x in 0...screen.w) {
				var cc = screen.pixels[x + y * screen.w];
				if (cc < 255) framePixels.setPixel(x, y, colors[cc]);
			}
		}
		frameTexture.uploadPixels(framePixels);
	}

	public function scheduleLevelChange(dir:Int) {
		pendingLevelChange = dir;
	}

	public function won() {
		wonTimer = 60 * 3;
		hasWon = true;
	}
}
