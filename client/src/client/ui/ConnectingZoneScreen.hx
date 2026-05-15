package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.res.DefaultFont;

class ConnectingZoneScreen extends Object {
  public function new(parent:Object) {
    super(parent);
    var t = new Text(DefaultFont.get(), this);
    t.text = "Connecting to zone...";
    t.x = 40; t.y = 100; t.scale(2);
  }
}
