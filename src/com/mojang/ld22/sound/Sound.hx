package com.mojang.ld22.sound;

class Sound {
	public static var playerHurt:Sound = new Sound("playerhurt.wav");
	public static var playerDeath:Sound = new Sound("death.wav");
	public static var monsterHurt:Sound = new Sound("monsterhurt.wav");
	public static var test:Sound = new Sound("test.wav");
	public static var pickup:Sound = new Sound("pickup.wav");
	public static var bossdeath:Sound = new Sound("bossdeath.wav");
	public static var craft:Sound = new Sound("craft.wav");

	var name:String;
	var sound:hxd.res.Sound;

	function new(name:String) {
		this.name = name;
	}

	function load() {
		if (sound != null) return;
		try {
			sound = hxd.Res.loader.loadCache(name, hxd.res.Sound);
		} catch (e:Dynamic) {
			trace("Failed to load sound: " + name + " - " + e);
		}
	}

	public function play() {
		load();
		if (sound != null) {
			sound.play();
		}
	}
}
