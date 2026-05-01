package;

import hxd.Key as HxdKey;

class InputHandler {
	public var keys:Array<InputKey> = [];

	public var up:InputKey;
	public var down:InputKey;
	public var left:InputKey;
	public var right:InputKey;
	public var attack:InputKey;
	public var menu:InputKey;
	public var mouseAttack:InputKey;
	public var mouseUse:InputKey;
	public var hotbarLeft:InputKey;
	public var hotbarRight:InputKey;

	public var mouseDir:Int = 0;

	public var hotbar:Array<InputKey>;

	var pad:hxd.Pad;
	var padConnected:Bool = false;
	var prevPadHotbarLeft:Bool = false;
	var prevPadHotbarRight:Bool = false;
	var prevPadAttack:Bool = false;
	var prevPadMenu:Bool = false;
	var prevPadUse:Bool = false;

	public function new() {
		up = new InputKey(this);
		down = new InputKey(this);
		left = new InputKey(this);
		right = new InputKey(this);
		attack = new InputKey(this);
		menu = new InputKey(this);
		mouseAttack = new InputKey(this);
		mouseUse = new InputKey(this);
		hotbarLeft = new InputKey(this);
		hotbarRight = new InputKey(this);
		hotbar = [];
		for (i in 0...8) hotbar.push(new InputKey(this));

		// Auto-detect gamepads
		hxd.Pad.wait(function(p) {
			pad = p;
			padConnected = true;
			pad.onDisconnect = function() {
				padConnected = false;
			};
		});
	}

	public function releaseAll() {
		for (i in 0...keys.length) {
			keys[i].releaseForFocusLoss();
		}
	}

	public function tick() {
		for (i in 0...keys.length) {
			keys[i].tick();
		}
	}

	public function updateKeys() {
		var window = hxd.Window.getInstance();
		var mx = window.mouseX * Game.WIDTH / window.width;
		var my = window.mouseY * Game.HEIGHT / window.height;
		var cx = Game.WIDTH / 2;
		var cy = (Game.HEIGHT - 8) / 2;
		var dx = mx - cx;
		var dy = my - cy;
		if (Math.abs(dx) > Math.abs(dy)) {
			mouseDir = dx > 0 ? 3 : 2;
		} else {
			mouseDir = dy > 0 ? 0 : 1;
		}

		// Keyboard input
		var kUp = HxdKey.isDown(HxdKey.NUMPAD_8) || HxdKey.isDown(HxdKey.W) || HxdKey.isDown(HxdKey.UP);
		var kDown = HxdKey.isDown(HxdKey.NUMPAD_2) || HxdKey.isDown(HxdKey.S) || HxdKey.isDown(HxdKey.DOWN);
		var kLeft = HxdKey.isDown(HxdKey.NUMPAD_4) || HxdKey.isDown(HxdKey.A) || HxdKey.isDown(HxdKey.LEFT);
		var kRight = HxdKey.isDown(HxdKey.NUMPAD_6) || HxdKey.isDown(HxdKey.D) || HxdKey.isDown(HxdKey.RIGHT);
		var kMenu = HxdKey.isDown(HxdKey.TAB) || HxdKey.isDown(HxdKey.ALT) || HxdKey.isDown(HxdKey.ENTER) || HxdKey.isDown(HxdKey.X);
		var kAttack = HxdKey.isDown(HxdKey.SPACE) || HxdKey.isDown(HxdKey.CTRL) || HxdKey.isDown(HxdKey.NUMPAD_0) || HxdKey.isDown(HxdKey.INSERT) || HxdKey.isDown(HxdKey.C);

		// Gamepad input (OR with keyboard)
		var pUp = kUp, pDown = kDown, pLeft = kLeft, pRight = kRight;
		var pAttack = kAttack, pMenu = kMenu;
		var pMouseAttack = HxdKey.isDown(HxdKey.MOUSE_LEFT);
		var pMouseUse = HxdKey.isDown(HxdKey.MOUSE_RIGHT);
		var pHotbarLeft = false;
		var pHotbarRight = false;

		if (padConnected && pad != null && pad.connected) {
			var cfg = pad.config;

			// Movement: left analog stick or D-pad
			var lx = pad.xAxis;
			var ly = pad.yAxis;
			pUp = kUp || (ly < -0.5) || pad.isDown(cfg.dpadUp);
			pDown = kDown || (ly > 0.5) || pad.isDown(cfg.dpadDown);
			pLeft = kLeft || (lx < -0.5) || pad.isDown(cfg.dpadLeft);
			pRight = kRight || (lx > 0.5) || pad.isDown(cfg.dpadRight);

			// A/X = attack, B/Y = use/menu, Start = menu
			// These use the player's current facing direction (no mouseDir override)
			pAttack = kAttack || pad.isDown(cfg.A) || pad.isDown(cfg.X);
			pMenu = kMenu || pad.isDown(cfg.B) || pad.isDown(cfg.Y) || pad.isDown(cfg.start);

			// LB/RB for hotbar cycling (use pressed edges)
			pHotbarLeft = pad.isPressed(cfg.LB);
			pHotbarRight = pad.isPressed(cfg.RB);
		}

		up.toggle(pUp);
		down.toggle(pDown);
		left.toggle(pLeft);
		right.toggle(pRight);
		menu.toggle(pMenu);
		attack.toggle(pAttack);
		mouseAttack.toggle(pMouseAttack);
		mouseUse.toggle(pMouseUse);
		hotbarLeft.toggle(pHotbarLeft);
		hotbarRight.toggle(pHotbarRight);

		for (i in 0...8) hotbar[i].toggle(HxdKey.isDown(HxdKey.NUMPAD_1 + i) || HxdKey.isDown(HxdKey.NUMBER_1 + i));
	}
}

class InputKey {
	public var presses:Int = 0;
	public var absorbs:Int = 0;
	public var down:Bool = false;
	public var clicked:Bool = false;

	var handler:InputHandler;
	var ignoreUntilRelease:Bool = false;

	public function new(handler:InputHandler) {
		this.handler = handler;
		handler.keys.push(this);
	}

	public function toggle(pressed:Bool) {
		if (ignoreUntilRelease) {
			if (!pressed) {
				ignoreUntilRelease = false;
			}
			return;
		}
		if (pressed != down) {
			down = pressed;
			if (pressed) {
				presses++;
			}
		}
	}

	public function releaseForFocusLoss() {
		if (down) {
			down = false;
			ignoreUntilRelease = true;
		}
	}

	public function tick() {
		if (absorbs < presses) {
			absorbs++;
			clicked = true;
		} else {
			clicked = false;
		}
	}
}
