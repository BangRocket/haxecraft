package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.Event;
import hxd.res.DefaultFont;

class LoginScreen extends Object {
  public var onSubmit:(username:String, password:String) -> Void;

  var usernameField:Text;
  var passwordField:Text;
  var statusField:Text;
  var focused:Int = 0;  // 0 = username, 1 = password
  var usernameValue:String = "";
  var passwordValue:String = "";

  public function new(parent:Object) {
    super(parent);
    var font = DefaultFont.get();

    var title = new Text(font, this);
    title.text = "haxecraft — login";
    title.x = 40; title.y = 40; title.scale(2);

    var unameLabel = new Text(font, this);
    unameLabel.text = "username:";
    unameLabel.x = 40; unameLabel.y = 120;

    usernameField = new Text(font, this);
    usernameField.x = 160; usernameField.y = 120;

    var pwLabel = new Text(font, this);
    pwLabel.text = "password:";
    pwLabel.x = 40; pwLabel.y = 160;

    passwordField = new Text(font, this);
    passwordField.x = 160; passwordField.y = 160;

    statusField = new Text(font, this);
    statusField.x = 40; statusField.y = 220;
    statusField.text = "Tab to switch field. Enter to submit.";

    refresh();
  }

  public function handleKey(e:Event):Void {
    switch e.kind {
      case EKeyDown:
        switch e.keyCode {
          case hxd.Key.TAB:
            focused = 1 - focused;
            refresh();
          case hxd.Key.ENTER:
            if (usernameValue.length > 0 && passwordValue.length > 0) {
              if (onSubmit != null) onSubmit(usernameValue, passwordValue);
              setStatus("connecting...");
            }
          case hxd.Key.BACKSPACE:
            if (focused == 0 && usernameValue.length > 0)
              usernameValue = usernameValue.substr(0, usernameValue.length - 1);
            else if (focused == 1 && passwordValue.length > 0)
              passwordValue = passwordValue.substr(0, passwordValue.length - 1);
            refresh();
          default:
        }
      case ETextInput:
        if (e.charCode > 31 && e.charCode < 127) {
          var ch = String.fromCharCode(e.charCode);
          if (focused == 0) usernameValue += ch;
          else passwordValue += ch;
          refresh();
        }
      default:
    }
  }

  function refresh():Void {
    usernameField.text = (focused == 0 ? "> " : "  ") + usernameValue + (focused == 0 ? "_" : "");
    var masked = StringTools.lpad("", "*", passwordValue.length);
    passwordField.text = (focused == 1 ? "> " : "  ") + masked + (focused == 1 ? "_" : "");
  }

  public function setStatus(s:String):Void {
    statusField.text = s;
  }
}
