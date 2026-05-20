package shared.proto;

enum abstract MsgType(Int) to Int from Int {
  // M0
  var HELLO = 1;
  var HELLO_ACK = 2;
  var LOGIN = 3;
  var LOGIN_ACK = 4;
  var ERROR = 5;
  // M1: handoff + zone lifecycle
  var ZONE_HANDOFF = 10;
  var ENTER_ZONE = 11;
  var ENTER_ZONE_ACK = 12;
  // M1: simulation
  var MOVE_INTENT = 20;
  var ENTITY_SPAWN = 21;
  var ENTITY_MOVE = 22;
  var ENTITY_DESPAWN = 23;
  // SP3: inventory
  var INVENTORY = 32;
  var SELECT_ACTIVE_ITEM = 34;
  // SP4: interactive tiles
  var USE_ITEM_ON_TILE = 35;
  var TILE_CHANGE = 36;
  // SP5: crafting
  var CRAFT = 37;
  var PLACE_FURNITURE = 38;
  // M2 SP2: chat
  var CHAT = 40;
}
