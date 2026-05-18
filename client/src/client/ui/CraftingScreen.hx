package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.res.DefaultFont;
import shared.item.RecipeBook;
import shared.item.CraftStation;

/** A keyboard-driven crafting menu — a scrolling recipe list. The server
    enforces station proximity and input availability. */
class CraftingScreen extends Object {
  public var onCraft:(recipeId:Int) -> Void;

  var font:h2d.Font;
  var lines:Array<Text> = [];
  var cursor:Int = 0;
  var scroll:Int = 0;
  static inline var VISIBLE = 12;

  public function new(parent:Object) {
    super(parent);
    font = DefaultFont.get();

    var title = new Text(font, this);
    title.text = "Crafting";
    title.x = 24; title.y = 12; title.scale(2);

    var hint = new Text(font, this);
    hint.x = 24; hint.y = 44;
    hint.text = "up/down move   Enter craft   C close";

    refresh();
  }

  public function handleKey(keyCode:Int):Void {
    if (keyCode == hxd.Key.UP) cursor--;
    else if (keyCode == hxd.Key.DOWN) cursor++;
    else if (keyCode == hxd.Key.ENTER) {
      if (onCraft != null) onCraft(RecipeBook.ALL[cursor].id);
      return;
    } else return;

    if (cursor < 0) cursor = 0;
    if (cursor >= RecipeBook.ALL.length) cursor = RecipeBook.ALL.length - 1;
    if (cursor < scroll) scroll = cursor;
    if (cursor >= scroll + VISIBLE) scroll = cursor - VISIBLE + 1;
    refresh();
  }

  function stationName(s:CraftStation):String {
    if (s == CraftStation.WORKBENCH) return "workbench";
    if (s == CraftStation.ANVIL) return "anvil";
    if (s == CraftStation.FURNACE) return "furnace";
    return "oven";
  }

  function refresh():Void {
    for (l in lines) l.remove();
    lines = [];
    var n = RecipeBook.ALL.length;
    for (i in 0...VISIBLE) {
      var idx = scroll + i;
      if (idx >= n) break;
      var r = RecipeBook.ALL[idx];
      var inputs = "";
      for (inp in r.inputs) {
        if (inputs.length > 0) inputs += ", ";
        inputs += inp.count + " " + inp.itemType.name();
      }
      var mark = (idx == cursor) ? "> " : "  ";
      var t = new Text(font, this);
      t.x = 24; t.y = 70 + i * 14;
      t.text = '$mark${r.output.name()} <- $inputs [${stationName(r.station)}]';
      lines.push(t);
    }
  }
}
