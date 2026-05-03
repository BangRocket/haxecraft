package game;

import engine.Engine;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.Screen;
import engine.gfx.SpriteSheet;
import engine.level.Level;
import engine.level.tile.Tile;
import engine.item.resource.Resource;
import engine.screen.Menu;
import game.entity.Player;
import game.crafting.Crafting;
import game.item.ResourceItem;
import game.screen.DeadMenu;
import game.screen.LevelTransitionMenu;
import game.screen.TitleMenu;
import game.screen.WonMenu;
import hxd.Window;

class Game extends Engine {
	public static inline var NAME = "Haxecraft";

	var input = new InputHandler();
	var level:Level;
	var levels:Array<Level> = [];
	var currentLevel = 3;
	var playerDeadTime = 0;
	var pendingLevelChange = 0;
	var wonTimer = 0;

	public var gameTime = 0;
	public var player:Player;
	public var menu:Menu;
	public var hasWon = false;

	public static function main() {
		hxd.Res.initLocal();
		new Game();
	}

	override function init() {
		super.init();
		var window = Window.getInstance();
		window.title = NAME;

		var icons = hxd.Res.load("icons.png").toImage().getPixels();
		var sprites = hxd.Res.load("sprites.png").toImage().getPixels();
		initScreen(320, 240, new SpriteSheet(icons), new SpriteSheet(sprites));

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
		if (menu != null) menu.init(cast this, input);
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

	override public function tick() {
		super.tick();
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

	override public function render() {
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

	public function scheduleLevelChange(dir:Int) {
		pendingLevelChange = dir;
	}

	public function won() {
		wonTimer = 60 * 3;
		hasWon = true;
	}
}
