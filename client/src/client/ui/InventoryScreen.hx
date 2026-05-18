package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.res.DefaultFont;
import shared.item.ItemType;

/** A keyboard-driven text-list inventory overlay. Toggled with I. */
class InventoryScreen extends Object {
  var font:h2d.Font;
  var lines:Array<Text> = [];

  public function new(parent:Object) {
    super(parent);
    font = DefaultFont.get();

    var title = new Text(font, this);
    title.text = "Inventory";
    title.x = 40; title.y = 30; title.scale(2);

    var hint = new Text(font, this);
    hint.x = 40; hint.y = 70;
    hint.text = "1-9 select active item    I close";
  }

  /** Re-render the slot list. */
  public function setSlots(slots:Array<{itemTypeId:Int, count:Int}>, activeSlot:Int):Void {
    for (l in lines) l.remove();
    lines = [];

    if (slots.length == 0) {
      var empty = new Text(font, this);
      empty.x = 40; empty.y = 100;
      empty.text = "(empty)";
      lines.push(empty);
      return;
    }
    for (i in 0...slots.length) {
      var s = slots[i];
      var it:ItemType = s.itemTypeId;
      var mark = (i == activeSlot) ? "> " : "  ";
      var t = new Text(font, this);
      t.x = 40; t.y = 100 + i * 16;
      t.text = '$mark${i + 1}. ${it.name()} x${s.count}';
      lines.push(t);
    }
  }
}
