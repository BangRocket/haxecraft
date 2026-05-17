package engine.screen;

import engine.gfx.Screen;

interface ListItem {
	function renderInventory(screen:Screen, x:Int, y:Int):Void;
}
