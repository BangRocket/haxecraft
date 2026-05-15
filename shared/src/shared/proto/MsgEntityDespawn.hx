package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgEntityDespawn implements Serializable {
  public var entityId:Int = 0;
  public function new() {}
}
