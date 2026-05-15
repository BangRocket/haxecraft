package client;

class Main extends hxd.App {
  static function main() {
    new Main();
  }
  override function init() {
    var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
    tf.text = "client stub";
  }
}
