package com.mojang.ld22.utils;

import haxe.Int64;

class Random {
	static final multiplier:Int64 = Int64.parseString("25214903917");
	static final addend:Int64 = Int64.ofInt(11);
	static final mask:Int64 = Int64.parseString("281474976710655"); // (1L << 48) - 1
	static var instanceCounter:Int = 0;

	var seed:Int64;
	var nextNextGaussian:Float;
	var haveNextNextGaussian:Bool = false;

	public function new(?seed:Int64) {
		if (seed != null) {
			setSeed(seed);
		} else {
			var time = Std.int(Sys.time() * 1000);
			instanceCounter++;
			this.seed = Int64.ofInt(time + instanceCounter);
			this.seed = (this.seed ^ multiplier) & mask;
		}
	}

	public function setSeed(seed:Int64) {
		this.seed = (seed ^ multiplier) & mask;
		haveNextNextGaussian = false;
	}

	function next(bits:Int):Int {
		seed = (seed * multiplier + addend) & mask;
		return Int64.toInt(seed >>> (48 - bits));
	}

	public function nextInt(?bound:Int):Int {
		if (bound == null) return next(32);
		if (bound <= 0) throw "bound must be positive";

		if ((bound & -bound) == bound) { // power of 2
			return Int64.toInt((Int64.make(0, bound) * Int64.make(0, next(31))) >> 31);
		}

		var bits:Int, val:Int;
		do {
			bits = next(31);
			val = bits % bound;
		} while (bits - val + (bound - 1) < 0);
		return val;
	}

	public function nextBoolean():Bool {
		return next(1) != 0;
	}

	public function nextFloat():Float {
		return next(24) / 16777216.0;
	}

	public function nextDouble():Float {
		return ((next(26) * 134217728.0) + next(27)) / 9007199254740992.0;
	}

	public function nextGaussian():Float {
		if (haveNextNextGaussian) {
			haveNextNextGaussian = false;
			return nextNextGaussian;
		} else {
			var v1:Float, v2:Float, s:Float;
			do {
				v1 = 2 * nextDouble() - 1;
				v2 = 2 * nextDouble() - 1;
				s = v1 * v1 + v2 * v2;
			} while (s >= 1 || s == 0);
			var mult = Math.sqrt(-2 * Math.log(s) / s);
			nextNextGaussian = v2 * mult;
			haveNextNextGaussian = true;
			return v1 * mult;
		}
	}
}
