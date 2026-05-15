package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.res.DefaultFont;

class WelcomeScreen extends Object {
  public function new(parent:Object, username:String) {
    super(parent);
    var font = DefaultFont.get();
    var t = new Text(font, this);
    t.text = 'Welcome, $username';
    t.x = 40; t.y = 100; t.scale(3);
  }
}
