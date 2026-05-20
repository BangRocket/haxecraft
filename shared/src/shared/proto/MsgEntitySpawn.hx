package shared.proto;

/** Server -> client: spawn an addressable entity. Mobiles vs. items are
    discriminated by `serial`'s top bit (0x40000000 — see server.zone.Serials):
    mobile range fills `name` + position; item range fills `itemTypeId` +
    `count` + position (or parent for carried items, though carried items
    are not spawned to other observers). Unused-for-this-kind fields are
    zero/empty. */
@:build(shared.proto.SerializableMacro.build())
class MsgEntitySpawn implements Serializable {
  public var entityId:Int = 0;       // legacy name kept for wire compat; really `serial`
  public var name:String = "";       // mobile only
  public var itemTypeId:Int = 0;     // item only
  public var count:Int = 0;          // item only
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public var parentSerial:Int = 0;   // item only; 0 = world-placed
  public var slot:Int = 0;           // item only; meaningful when parentSerial != 0
  public var hp:Int = 0;             // mobile only
  public var maxHp:Int = 0;          // mobile only
  public function new() {}
}
