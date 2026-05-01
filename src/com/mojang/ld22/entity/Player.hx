package com.mojang.ld22.entity;

import com.mojang.ld22.Game;
import com.mojang.ld22.InputHandler;
import com.mojang.ld22.entity.particle.TextParticle;
import com.mojang.ld22.gfx.Color;
import com.mojang.ld22.gfx.Screen;
import com.mojang.ld22.item.FurnitureItem;
import com.mojang.ld22.item.Item;
import com.mojang.ld22.item.PowerGloveItem;
import com.mojang.ld22.level.Level;
import com.mojang.ld22.level.tile.Tile;
import com.mojang.ld22.screen.InventoryMenu;
import com.mojang.ld22.sound.Sound;

class Player extends Mob {
	private var input:InputHandler;
	private var attackTime:Int;
	private var attackDir:Int;

	public var game:Game;
	public var inventory:Inventory = new Inventory();
	public var hotbar:Array<Item> = [];
	public var hotbarSelection:Int = 0;
	public var attackItem:Item;
	public var activeItem:Item;
	public var stamina:Int;
	public var staminaRecharge:Int;
	public var staminaRechargeDelay:Int;
	public var score:Int;
	public var maxStamina:Int = 10;
	private var onStairDelay:Int;
	public var invulnerableTime:Int = 0;

	public function new(game:Game, input:InputHandler) {
		super();
		this.game = game;
		this.input = input;
		x = 24;
		y = 24;
		stamina = maxStamina;

		inventory.add(new FurnitureItem(new Workbench()));
		inventory.add(new PowerGloveItem());

		for (i in 0...8) hotbar.push(null);
	}

	override public function tick() {
		super.tick();

		if (invulnerableTime > 0) invulnerableTime--;
		var onTile = level.getTile(x >> 4, y >> 4);
		if (onTile == Tile.stairsDown || onTile == Tile.stairsUp) {
			if (onStairDelay == 0) {
				changeLevel((onTile == Tile.stairsUp) ? 1 : -1);
				onStairDelay = 10;
				return;
			}
			onStairDelay = 10;
		} else {
			if (onStairDelay > 0) onStairDelay--;
		}

		if (stamina <= 0 && staminaRechargeDelay == 0 && staminaRecharge == 0) {
			staminaRechargeDelay = 40;
		}

		if (staminaRechargeDelay > 0) {
			staminaRechargeDelay--;
		}

		if (staminaRechargeDelay == 0) {
			staminaRecharge++;
			if (isSwimming()) {
				staminaRecharge = 0;
			}
			while (staminaRecharge > 10) {
				staminaRecharge -= 10;
				if (stamina < maxStamina) stamina++;
			}
		}

		var xa = 0;
		var ya = 0;
		if (input.up.down) ya--;
		if (input.down.down) ya++;
		if (input.left.down) xa--;
		if (input.right.down) xa++;
		if (isSwimming() && tickTime % 60 == 0) {
			if (stamina > 0) {
				stamina--;
			} else {
				hurt(this, 1, dir ^ 1);
			}
		}

		if (staminaRechargeDelay % 2 == 0) {
			move(xa, ya);
		}

		if (input.mouseAttack.clicked) {
			dir = input.mouseDir;
			if (stamina == 0) {

			} else {
				stamina--;
				staminaRecharge = 0;
				attack();
			}
		} else if (input.attack.clicked) {
			if (stamina == 0) {

			} else {
				stamina--;
				staminaRecharge = 0;
				attack();
			}
		}
		if (input.mouseUse.clicked) {
			dir = input.mouseDir;
			tryUse();
		} else if (input.menu.clicked) {
			if (!tryUse()) {
				game.setMenu(new InventoryMenu(this));
			}
		}
		for (i in 0...8) {
			if (input.hotbar[i].clicked) {
				hotbarSelection = i;
				// Return current activeItem to inventory if it exists
				if (activeItem != null) {
					inventory.add(activeItem);
					activeItem = null;
				}
				// Equip hotbar slot
				if (hotbar[i] != null) {
					activeItem = hotbar[i];
					hotbar[i] = null;
				}
				break;
			}
		}
		if (attackTime > 0) attackTime--;
	}

	private function tryUse():Bool {
		var yo = -2;
		if (dir == 0 && useArea(x - 8, y + 4 + yo, x + 8, y + 12 + yo)) return true;
		if (dir == 1 && useArea(x - 8, y - 12 + yo, x + 8, y - 4 + yo)) return true;
		if (dir == 3 && useArea(x + 4, y - 8 + yo, x + 12, y + 8 + yo)) return true;
		if (dir == 2 && useArea(x - 12, y - 8 + yo, x - 4, y + 8 + yo)) return true;

		var xt = x >> 4;
		var yt = (y + yo) >> 4;
		var r = 12;
		if (attackDir == 0) yt = (y + r + yo) >> 4;
		if (attackDir == 1) yt = (y - r + yo) >> 4;
		if (attackDir == 2) xt = (x - r) >> 4;
		if (attackDir == 3) xt = (x + r) >> 4;

		if (xt >= 0 && yt >= 0 && xt < level.w && yt < level.h) {
			if (level.getTile(xt, yt).use(level, xt, yt, this, attackDir)) return true;
		}

		return false;
	}

	private function attack() {
		walkDist += 8;
		attackDir = dir;
		attackItem = activeItem;
		var done = false;

		if (activeItem != null) {
			attackTime = 10;
			var yo = -2;
			var range = 12;
			if (dir == 0 && interactArea(x - 8, y + 4 + yo, x + 8, y + range + yo)) done = true;
			if (dir == 1 && interactArea(x - 8, y - range + yo, x + 8, y - 4 + yo)) done = true;
			if (dir == 3 && interactArea(x + 4, y - 8 + yo, x + range, y + 8 + yo)) done = true;
			if (dir == 2 && interactArea(x - range, y - 8 + yo, x - 4, y + 8 + yo)) done = true;
			if (done) return;

			var xt = x >> 4;
			var yt = (y + yo) >> 4;
			var r = 12;
			if (attackDir == 0) yt = (y + r + yo) >> 4;
			if (attackDir == 1) yt = (y - r + yo) >> 4;
			if (attackDir == 2) xt = (x - r) >> 4;
			if (attackDir == 3) xt = (x + r) >> 4;

			if (xt >= 0 && yt >= 0 && xt < level.w && yt < level.h) {
				if (activeItem.interactOn(level.getTile(xt, yt), level, xt, yt, this, attackDir)) {
					done = true;
				} else {
					if (level.getTile(xt, yt).interact(level, xt, yt, this, activeItem, attackDir)) {
						done = true;
					}
				}
				if (activeItem.isDepleted()) {
					activeItem = null;
				}
			}
		}

		if (done) return;

		if (activeItem == null || activeItem.canAttack()) {
			attackTime = 5;
			var yo = -2;
			var range = 20;
			if (dir == 0) hurtArea(x - 8, y + 4 + yo, x + 8, y + range + yo);
			if (dir == 1) hurtArea(x - 8, y - range + yo, x + 8, y - 4 + yo);
			if (dir == 3) hurtArea(x + 4, y - 8 + yo, x + range, y + 8 + yo);
			if (dir == 2) hurtArea(x - range, y - 8 + yo, x - 4, y + 8 + yo);

			var xt = x >> 4;
			var yt = (y + yo) >> 4;
			var r = 12;
			if (attackDir == 0) yt = (y + r + yo) >> 4;
			if (attackDir == 1) yt = (y - r + yo) >> 4;
			if (attackDir == 2) xt = (x - r) >> 4;
			if (attackDir == 3) xt = (x + r) >> 4;

			if (xt >= 0 && yt >= 0 && xt < level.w && yt < level.h) {
				level.getTile(xt, yt).hurt(level, xt, yt, this, random.nextInt(3) + 1, attackDir);
			}
		}
	}

	private function useArea(x0:Int, y0:Int, x1:Int, y1:Int):Bool {
		var entities = level.getEntities(x0, y0, x1, y1);
		for (i in 0...entities.length) {
			var e = entities[i];
			if (e != this) if (e.use(this, attackDir)) return true;
		}
		return false;
	}

	private function interactArea(x0:Int, y0:Int, x1:Int, y1:Int):Bool {
		var entities = level.getEntities(x0, y0, x1, y1);
		for (i in 0...entities.length) {
			var e = entities[i];
			if (e != this) if (e.interact(this, activeItem, attackDir)) return true;
		}
		return false;
	}

	private function hurtArea(x0:Int, y0:Int, x1:Int, y1:Int) {
		var entities = level.getEntities(x0, y0, x1, y1);
		for (i in 0...entities.length) {
			var e = entities[i];
			if (e != this) e.hurt(this, getAttackDamage(e), attackDir);
		}
	}

	private function getAttackDamage(e:Entity):Int {
		var dmg = random.nextInt(3) + 1;
		if (attackItem != null) {
			dmg += attackItem.getAttackDamageBonus(e);
		}
		return dmg;
	}

	override public function render(screen:Screen) {
		var xt = 0;
		var yt = 14;

		var flip1 = (walkDist >> 3) & 1;
		var flip2 = (walkDist >> 3) & 1;

		if (dir == 1) {
			xt += 2;
		}
		if (dir > 1) {
			flip1 = 0;
			flip2 = ((walkDist >> 4) & 1);
			if (dir == 2) {
				flip1 = 1;
			}
			xt += 4 + ((walkDist >> 3) & 1) * 2;
		}

		var xo = x - 8;
		var yo = y - 11;
		if (isSwimming()) {
			yo += 4;
			var waterColor = Color.get(-1, -1, 115, 335);
			if (Std.int(tickTime / 8) % 2 == 0) {
				waterColor = Color.get(-1, 335, 5, 115);
			}
			screen.render(xo + 0, yo + 3, 5 + 13 * 32, waterColor, 0);
			screen.render(xo + 8, yo + 3, 5 + 13 * 32, waterColor, 1);
		}

		if (attackTime > 0 && attackDir == 1) {
			screen.render(xo + 0, yo - 4, 6 + 13 * 32, Color.get(-1, 555, 555, 555), 0);
			screen.render(xo + 8, yo - 4, 6 + 13 * 32, Color.get(-1, 555, 555, 555), 1);
			if (attackItem != null) {
				attackItem.renderIcon(screen, xo + 4, yo - 4);
			}
		}
		var col = Color.get(-1, 100, 220, 532);
		if (hurtTime > 0) {
			col = Color.get(-1, 555, 555, 555);
		}

		if (Std.isOfType(activeItem, FurnitureItem)) {
			yt += 2;
		}
		screen.render(xo + 8 * flip1, yo + 0, xt + yt * 32, col, flip1);
		screen.render(xo + 8 - 8 * flip1, yo + 0, xt + 1 + yt * 32, col, flip1);
		if (!isSwimming()) {
			screen.render(xo + 8 * flip2, yo + 8, xt + (yt + 1) * 32, col, flip2);
			screen.render(xo + 8 - 8 * flip2, yo + 8, xt + 1 + (yt + 1) * 32, col, flip2);
		}

		if (attackTime > 0 && attackDir == 2) {
			screen.render(xo - 4, yo, 7 + 13 * 32, Color.get(-1, 555, 555, 555), 1);
			screen.render(xo - 4, yo + 8, 7 + 13 * 32, Color.get(-1, 555, 555, 555), 3);
			if (attackItem != null) {
				attackItem.renderIcon(screen, xo - 4, yo + 4);
			}
		}
		if (attackTime > 0 && attackDir == 3) {
			screen.render(xo + 8 + 4, yo, 7 + 13 * 32, Color.get(-1, 555, 555, 555), 0);
			screen.render(xo + 8 + 4, yo + 8, 7 + 13 * 32, Color.get(-1, 555, 555, 555), 2);
			if (attackItem != null) {
				attackItem.renderIcon(screen, xo + 8 + 4, yo + 4);
			}
		}
		if (attackTime > 0 && attackDir == 0) {
			screen.render(xo + 0, yo + 8 + 4, 6 + 13 * 32, Color.get(-1, 555, 555, 555), 2);
			screen.render(xo + 8, yo + 8 + 4, 6 + 13 * 32, Color.get(-1, 555, 555, 555), 3);
			if (attackItem != null) {
				attackItem.renderIcon(screen, xo + 4, yo + 8 + 4);
			}
		}

		if (Std.isOfType(activeItem, FurnitureItem)) {
			var furniture = cast(activeItem, FurnitureItem).furniture;
			furniture.x = x;
			furniture.y = yo;
			furniture.render(screen);
		}
	}

	override public function touchItem(itemEntity:ItemEntity) {
		itemEntity.take(this);
		inventory.add(itemEntity.item);
	}

	override public function canSwim():Bool {
		return true;
	}

	override public function findStartPos(level:Level):Bool {
		while (true) {
			var x = random.nextInt(level.w);
			var y = random.nextInt(level.h);
			if (level.getTile(x, y) == Tile.grass) {
				this.x = x * 16 + 8;
				this.y = y * 16 + 8;
				return true;
			}
		}
	}

	public function payStamina(cost:Int):Bool {
		if (cost > stamina) return false;
		stamina -= cost;
		return true;
	}

	public function changeLevel(dir:Int) {
		game.scheduleLevelChange(dir);
	}

	override public function getLightRadius():Int {
		var r = 2;
		if (activeItem != null) {
			if (Std.isOfType(activeItem, FurnitureItem)) {
				var rr = cast(activeItem, FurnitureItem).furniture.getLightRadius();
				if (rr > r) r = rr;
			}
		}
		return r;
	}

	override function die() {
		super.die();
		Sound.playerDeath.play();
	}

	override function touchedBy(entity:Entity) {
		if (!Std.isOfType(entity, Player)) {
			entity.touchedBy(this);
		}
	}

	override function doHurt(damage:Int, attackDir:Int) {
		if (hurtTime > 0 || invulnerableTime > 0) return;

		Sound.playerHurt.play();
		level.add(new TextParticle("" + damage, x, y, Color.get(-1, 504, 504, 504)));
		health -= damage;
		if (attackDir == 0) yKnockback = 6;
		if (attackDir == 1) yKnockback = -6;
		if (attackDir == 2) xKnockback = -6;
		if (attackDir == 3) xKnockback = 6;
		hurtTime = 10;
		invulnerableTime = 30;
	}

	public function gameWon() {
		level.player.invulnerableTime = 60 * 5;
		game.won();
	}
}
