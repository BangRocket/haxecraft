package engine;

import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.GpuRenderer;
import engine.gfx.Screen;
import engine.gfx.SpriteSheet;
import engine.screen.Menu;
import hxd.Window;

class Engine extends hxd.App {
	public static var WIDTH:Int = 320;
	public static var HEIGHT:Int = 240;
	public static var SCALE:Float = 4;
	public static var displayOffsetX = 0;
	public static var displayOffsetY = 0;

	public var screen:Screen;
	public var lightScreen:Screen;
	public var gpuRenderer:GpuRenderer;
	public var tickCount = 0;

	var accumulator = 0.0;

	function initScreen(w:Int, h:Int, iconSheet:SpriteSheet, ?spriteSheet:SpriteSheet) {
		WIDTH = w;
		HEIGHT = h;
		screen = new Screen(w, h, iconSheet, spriteSheet);
		lightScreen = new Screen(w, h, iconSheet);
		gpuRenderer = new GpuRenderer(w, h, iconSheet, spriteSheet, s2d);
		screen.gpu = gpuRenderer;
	}

	override function update(dt:Float) {
		accumulator += dt * 60;
		while (accumulator >= 1) {
			tick();
			accumulator--;
		}
		renderFrame();
	}

	public function tick() {
		tickCount++;
	}

	public function renderFrame() {
		gpuRenderer.beginFrame();
		gpuRenderer.endFrame();
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

	public function renderFocusNagger() {
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
}
