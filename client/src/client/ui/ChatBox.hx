package client.ui;

import h2d.Object;
import h2d.Text;
import hxd.Event;
import hxd.res.DefaultFont;

/**
 * Minimal chat overlay docked bottom-left of the 320x240 logical screen.
 * Shows the last few messages; an input line opens on Enter.
 */
class ChatBox extends Object {
  static inline var MAX_LINES = 3;

  public var inputActive(default, null):Bool = false;
  public var onSubmit:String -> Void;

  var lines:Array<String> = [];
  var lineTexts:Array<Text> = [];
  var inputText:Text;
  var inputValue:String = "";

  public function new(parent:Object) {
    super(parent);
    var font = DefaultFont.get();
    for (i in 0...MAX_LINES) {
      var t = new Text(font, this);
      t.setScale(0.5);
      t.x = 4;
      t.y = 200 + i * 11;
      lineTexts.push(t);
    }
    inputText = new Text(font, this);
    inputText.setScale(0.5);
    inputText.x = 4;
    inputText.y = 200 + MAX_LINES * 11;
    inputText.visible = false;
    refresh();
  }

  public function addMessage(s:String):Void {
    lines.push(s);
    if (lines.length > MAX_LINES) lines.shift();
    refresh();
  }

  public function handleKey(e:Event):Void {
    if (!inputActive) {
      if (e.kind == EKeyDown && e.keyCode == hxd.Key.ENTER) {
        inputActive = true;
        inputValue = "";
        inputText.visible = true;
        refresh();
      }
      return;
    }
    switch e.kind {
      case EKeyDown:
        switch e.keyCode {
          case hxd.Key.ENTER:
            var v = inputValue;
            closeInput();
            if (v.length > 0 && onSubmit != null) onSubmit(v);
          case hxd.Key.ESCAPE:
            closeInput();
          case hxd.Key.BACKSPACE:
            if (inputValue.length > 0) {
              inputValue = inputValue.substr(0, inputValue.length - 1);
              refresh();
            }
          default:
        }
      case ETextInput:
        if (e.charCode > 31 && e.charCode < 127) {
          inputValue += String.fromCharCode(e.charCode);
          refresh();
        }
      default:
    }
  }

  function closeInput():Void {
    inputActive = false;
    inputValue = "";
    inputText.visible = false;
    refresh();
  }

  function refresh():Void {
    for (i in 0...MAX_LINES) {
      lineTexts[i].text = (i < lines.length) ? lines[i] : "";
    }
    inputText.text = "> " + inputValue + "_";
  }
}
