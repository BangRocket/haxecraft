package com.mojang.ld22.screen;

import com.mojang.ld22.gfx.Screen;

interface ListItem {
	function renderInventory(screen:Screen, x:Int, y:Int):Void;
}
