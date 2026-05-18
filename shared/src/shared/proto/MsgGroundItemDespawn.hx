package shared.proto;

/** Server -> client: a ground item left the world (picked up in SP3). */
@:build(shared.proto.SerializableMacro.build())
class MsgGroundItemDespawn implements Serializable {
  public var worldItemId:Int = 0;
  public function new() {}
}
