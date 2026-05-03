package game.screen;

import engine.screen.Menu;
import game.Game;

class GameMenu extends Menu {
	public var game(get, never):Game;

	inline function get_game():Game {
		return cast engine;
	}
}
