package shared.proto;

/** Server -> client: an item lying in the world. SP2 sends these in the
    zone-entry burst; they are static (no move/despawn until SP3 pickup). */
@:build(shared.proto.SerializableMacro.build())
class MsgGroundItemSpawn implements Serializable {
  public var worldItemId:Int = 0;
  public var itemTypeId:Int = 0;
  public var count:Int = 0;
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public function new() {}
}
