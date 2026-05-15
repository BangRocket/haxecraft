package engine;

import engine.gfx.ChromeText;
import engine.gfx.Color;
import engine.gfx.Font;
import engine.gfx.GpuRenderer;
import engine.gfx.Screen;
import engine.gfx.SpriteSheet;
import engine.gfx.ttf.RuntimeFont;
import engine.screen.Menu;
import game.SpriteNames;
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

	// Rolling FPS counter — frames in the last second.
	var fpsFrames:Int = 0;
	var fpsAccum:Float = 0;
	public var fps:Int = 0;

	var accumulator = 0.0;

	override function init() {
		Screen.initPalette();
	}

	function initScreen(w:Int, h:Int) {
		WIDTH = w;
		HEIGHT = h;
		screen = new Screen(w, h);
		lightScreen = new Screen(w, h);
		gpuRenderer = new GpuRenderer(w, h, s2d);
		screen.gpu = gpuRenderer;

		// TTF overlay (FPS, debug labels). Added to s2d after gpuRenderer's
		// tileGroup so it z-orders on top.
		ChromeText.init(s2d);
		var mago = hxd.Res.load("assets/font/mago1.ttf").entry.getBytes();
		ChromeText.setFont(RuntimeFont.build(mago, 8));
	}

	override function update(dt:Float) {
		fpsAccum += dt;
		fpsFrames++;
		if (fpsAccum >= 1) {
			fps = fpsFrames;
			fpsFrames = 0;
			fpsAccum -= 1;
		}

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
		ChromeText.beginFrame();
		ChromeText.draw('FPS $fps', 2, 2, 0xFFFFFF);
		ChromeText.endFrame();
		gpuRenderer.endFrame();
	}

	function updateDisplayScale() {
		var window = Window.getInstance();
		var w = window.width;
		var h = window.height;
		var sx = w / WIDTH;
		var sy = h / HEIGHT;
		gpuRenderer.setScale(sx, sy);
		ChromeText.setScale(sx, sy);
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

		screen.renderSprite(xx - 8, yy - 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 0);
		screen.renderSprite(xx + w * 8, yy - 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 1);
		screen.renderSprite(xx - 8, yy + 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 2);
		screen.renderSprite(xx + w * 8, yy + 8, SpriteNames.UI_FRAME_CORNER, Color.get(-1, 1, 5, 445), 3);
		for (x in 0...w) {
			screen.renderSprite(xx + x * 8, yy - 8, SpriteNames.UI_FRAME_HORIZ, Color.get(-1, 1, 5, 445), 0);
			screen.renderSprite(xx + x * 8, yy + 8, SpriteNames.UI_FRAME_HORIZ, Color.get(-1, 1, 5, 445), 2);
		}
		for (y in 0...h) {
			screen.renderSprite(xx - 8, yy + y * 8, SpriteNames.UI_FRAME_VERT, Color.get(-1, 1, 5, 445), 0);
			screen.renderSprite(xx + w * 8, yy + y * 8, SpriteNames.UI_FRAME_VERT, Color.get(-1, 1, 5, 445), 1);
		}

		if (Std.int(tickCount / 20) % 2 == 0)
			Font.draw(msg, screen, xx, yy, Color.get(5, 333, 333, 333));
		else
			Font.draw(msg, screen, xx, yy, Color.get(5, 555, 555, 555));
	}
}
