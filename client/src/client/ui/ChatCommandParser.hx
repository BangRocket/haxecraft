package client.ui;

import shared.proto.ChatChannel;

/** Parses a typed chat line into a channel + body. Pure — no I/O. */
class ChatCommandParser {
  /** Canned emote command -> action text. */
  public static var CANNED_EMOTES(default, null):Map<String, String> = [
    "wave"  => "waves.",
    "bow"   => "bows.",
    "laugh" => "laughs.",
    "cheer" => "cheers!",
    "dance" => "dances.",
  ];

  public static function parse(input:String):{channel:Int, text:String} {
    if (input.charAt(0) != "/") {
      return { channel: (ChatChannel.SAY : Int), text: input };
    }
    var sp = input.indexOf(" ");
    var cmd = (sp < 0 ? input.substr(1) : input.substring(1, sp));
    var rest = (sp < 0 ? "" : input.substr(sp + 1));

    if (cmd == "g") {
      return { channel: (ChatChannel.GLOBAL : Int), text: rest };
    }
    if (cmd == "me") {
      return { channel: (ChatChannel.EMOTE : Int), text: rest };
    }
    if (CANNED_EMOTES.exists(cmd)) {
      return { channel: (ChatChannel.EMOTE : Int), text: CANNED_EMOTES.get(cmd) };
    }
    // Unknown command — treat the whole line as say text.
    return { channel: (ChatChannel.SAY : Int), text: input };
  }
}
