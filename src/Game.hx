package;

import entity.Player;
import crafting.Crafting;
import gfx.Color;
import gfx.Font;
import gfx.GpuRenderer;
import gfx.Screen;
import gfx.SpriteSheet;
import level.Level;
import level.tile.Tile;
import item.resource.Resource;
import item.ResourceItem;
import screen.DeadMenu;
import screen.LevelTransitionMenu;
import screen.Menu;
import screen.TitleMenu;
import screen.WonMenu;
import hxd.Window;

class Game extends hxd.App {
	public static inline var NAME = "Haxecraft";
	public static inline var HEIGHT = 240;
	public static inline var WIDTH = 320;
	public static var SCALE:Float = 4;
	public static var displayOffsetX = 0;
	public static var displayOffsetY = 0;

	var screen:Screen;
	var lightScreen:Screen;
	var gpuRenderer:GpuRenderer;
	var input = new InputHandler();
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

		initPalette();
		var icons = hxd.Res.load("icons.png").toImage().getPixels();
		var sprites = hxd.Res.load("sprites.png").toImage().getPixels();
		var iconSheet = new SpriteSheet(icons);
		var spriteSheet = new SpriteSheet(sprites);
		screen = new Screen(WIDTH, HEIGHT, iconSheet, spriteSheet);
		lightScreen = new Screen(WIDTH, HEIGHT, iconSheet);

		gpuRenderer = new GpuRenderer(WIDTH, HEIGHT, colors, iconSheet, spriteSheet, s2d);
		screen.gpu = gpuRenderer;

		updateDisplayScale();
		window.resize(1280, 960);

		Tile.init();
		Resource.init();
		Crafting.init();
		resetGame();
		setMenu(new TitleMenu());
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
		gpuRenderer.beginFrame();

		var xScroll = player.x - Std.int(screen.w / 2);
		var yScroll = player.y - Std.int((screen.h - 8) / 2);
		if (xScroll < 16) xScroll = 16;
		if (yScroll < 16) yScroll = 16;
		if (xScroll > level.w * 16 - screen.w - 16) xScroll = level.w * 16 - screen.w - 16;
		if (yScroll > level.h * 16 - screen.h - 16) yScroll = level.h * 16 - screen.h - 16;
		if (currentLevel > 3) {
			var rows = Std.int((screen.h + 15) / 8) + 1;
			var cols = Std.int((screen.w + 15) / 8) + 1;
			for (y in 0...rows) {
				for (x in 0...cols) {
					screen.render(x * 8 - ((Std.int(xScroll / 4)) & 7), y * 8 - ((Std.int(yScroll / 4)) & 7), 0, 0);
				}
			}
		}

		level.renderBackground(screen, xScroll, yScroll);
		level.renderSprites(screen, xScroll, yScroll);

		if (currentLevel < 3) {
			lightScreen.clearLight(0);
			level.renderLight(lightScreen, xScroll, yScroll);
			screen.overlay(lightScreen, xScroll, yScroll);
		} else {
			gpuRenderer.hideOverlay();
		}

		if (menu != null) {
			menu.render(screen);
		} else {
			renderGui();
		}
		if (!hxd.Window.getInstance().isFocused) renderFocusNagger();

		gpuRenderer.endFrame();
	}

	function renderGui() {
		for (y in 0...2) {
			for (x in 0...20) {
				screen.render(x * 8, screen.h - 16 + y * 8, 0 + 12 * 32, 0);
			}
		}

		for (i in 0...10) {
			if (i < player.health)
				screen.render(i * 8, screen.h - 16, 0 + 12 * 32, 0);
			else
				screen.render(i * 8, screen.h - 16, 0 + 12 * 32, 0);

			if (player.staminaRechargeDelay > 0) {
				if (Std.int(player.staminaRechargeDelay / 4) % 2 == 0)
					screen.render(i * 8, screen.h - 8, 1 + 12 * 32, 0);
				else
					screen.render(i * 8, screen.h - 8, 1 + 12 * 32, 0);
			} else if (i < player.stamina) {
				screen.render(i * 8, screen.h - 8, 1 + 12 * 32, 0);
			} else {
				screen.render(i * 8, screen.h - 8, 1 + 12 * 32, 0);
			}
		}
		if (player.activeItem != null) {
			player.activeItem.renderInventory(screen, 10 * 8, screen.h - 16);
		}

		renderQuickbar();
	}

	function renderQuickbar() {
		var slotSize = 16;
		var slotCount = 8;
		var totalW = slotCount * slotSize;
		var startX = Std.int((screen.w - totalW) / 2);
		var startY = screen.h - 38;

		for (i in 0...slotCount) {
			var sx = startX + i * slotSize;
			var sy = startY;
			var isSelected = (i == player.hotbarSelection && player.activeItem == null);

			var bgCol = isSelected ? Color.get(0, 555, 555, 555) : Color.get(0, 111, 111, 111);
			screen.render(sx, sy, 0 + 12 * 32, bgCol, 0);

			var item = player.hotbar[i];
			if (item != null) {
				item.renderIcon(screen, sx + 4, sy + 4);
				if (Std.isOfType(item, ResourceItem)) {
					var ri = cast(item, ResourceItem);
					if (ri.count > 1) {
						Font.draw("" + ri.count, screen, sx + 4, sy + 8, Color.get(-1, 555, 555, 555));
					}
				}
			}

			Font.draw("" + (i + 1), screen, sx + 4, sy - 8, Color.get(0, 333, 333, 333));
		}

		if (player.activeItem != null) {
			var ax = startX + player.hotbarSelection * slotSize;
			var ay = startY;
			var hiCol = Color.get(0, 555, 555, 0);
			screen.render(ax - 1, ay - 1, 0 + 12 * 32, hiCol, 0);
			screen.render(ax + slotSize, ay - 1, 0 + 12 * 32, hiCol, 0);
			screen.render(ax - 1, ay + slotSize, 0 + 12 * 32, hiCol, 0);
			screen.render(ax + slotSize, ay + slotSize, 0 + 12 * 32, hiCol, 0);
		}
	}

	function updateDisplayScale() {
		var window = Window.getInstance();
		var w = window.width;
		var h = window.height;
		var sx = w / WIDTH;
		var sy = h / HEIGHT;
		gpuRenderer.setScale(sx, sy);
		displayOffsetX = 0;
		displayOffsetY = 0;
		SCALE = sx < sy ? sx : sy;
	}

	override function onResize() {
		updateDisplayScale();
	}

	function renderFocusNagger() {
		var msg = "Click to focus!";
		var xx = Std.int((WIDTH - msg.length * 8) / 2);
		var yy = Std.int((HEIGHT - 8) / 2);
		var w = msg.length;
		var h = 1;

		screen.render(xx - 8, yy - 8, 0 + 13 * 32, 0);
		screen.render(xx + w * 8, yy - 8, 0 + 13 * 32, 1);
		screen.render(xx - 8, yy + 8, 0 + 13 * 32, 2);
		screen.render(xx + w * 8, yy + 8, 0 + 13 * 32, 3);
		for (x in 0...w) {
			screen.render(xx + x * 8, yy - 8, 1 + 13 * 32, 0);
			screen.render(xx + x * 8, yy + 8, 1 + 13 * 32, 2);
		}
		for (y in 0...h) {
			screen.render(xx - 8, yy + y * 8, 2 + 13 * 32, 0);
			screen.render(xx + w * 8, yy + y * 8, 2 + 13 * 32, 1);
		}

		if (Std.int(tickCount / 20) % 2 == 0)
			Font.draw(msg, screen, xx, yy, Color.get(5, 333, 333, 333));
		else
			Font.draw(msg, screen, xx, yy, Color.get(5, 555, 555, 555));
	}

	public function scheduleLevelChange(dir:Int) {
		pendingLevelChange = dir;
	}

	public function won() {
		wonTimer = 60 * 3;
		hasWon = true;
	}
}
