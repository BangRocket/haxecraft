package shared.proto;

enum abstract ChatChannel(Int) to Int from Int {
  var SAY = 0;
  var GLOBAL = 1;
  var EMOTE = 2;
}
