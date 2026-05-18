package shared.proto;

/** Server -> client: a placed furniture object in the world. SP2 sends these
    in the zone-entry burst; they are static and collidable. */
@:build(shared.proto.SerializableMacro.build())
class MsgWorldObjectSpawn implements Serializable {
  public var objectId:Int = 0;
  public var objectTypeId:Int = 0;
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public function new() {}
}
