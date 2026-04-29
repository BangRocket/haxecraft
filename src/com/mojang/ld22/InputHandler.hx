package com.mojang.ld22;

import hxd.Key as HxdKey;

class InputHandler {
	public var keys:Array<InputKey> = [];

	public var up:InputKey;
	public var down:InputKey;
	public var left:InputKey;
	public var right:InputKey;
	public var attack:InputKey;
	public var menu:InputKey;

	public function new() {
		up = new InputKey(this);
		down = new InputKey(this);
		left = new InputKey(this);
		right = new InputKey(this);
		attack = new InputKey(this);
		menu = new InputKey(this);
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
		up.toggle(HxdKey.isDown(HxdKey.NUMPAD_8) || HxdKey.isDown(HxdKey.W) || HxdKey.isDown(HxdKey.UP));
		down.toggle(HxdKey.isDown(HxdKey.NUMPAD_2) || HxdKey.isDown(HxdKey.S) || HxdKey.isDown(HxdKey.DOWN));
		left.toggle(HxdKey.isDown(HxdKey.NUMPAD_4) || HxdKey.isDown(HxdKey.A) || HxdKey.isDown(HxdKey.LEFT));
		right.toggle(HxdKey.isDown(HxdKey.NUMPAD_6) || HxdKey.isDown(HxdKey.D) || HxdKey.isDown(HxdKey.RIGHT));

		menu.toggle(HxdKey.isDown(HxdKey.TAB) || HxdKey.isDown(HxdKey.ALT) || HxdKey.isDown(HxdKey.ENTER) || HxdKey.isDown(HxdKey.X));
		attack.toggle(HxdKey.isDown(HxdKey.SPACE) || HxdKey.isDown(HxdKey.CTRL) || HxdKey.isDown(HxdKey.NUMPAD_0) || HxdKey.isDown(HxdKey.INSERT) || HxdKey.isDown(HxdKey.C));
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
