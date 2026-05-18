package shared.proto;

/** Client -> server: select the active inventory slot. */
@:build(shared.proto.SerializableMacro.build())
class MsgSelectActiveItem implements Serializable {
  public var slot:Int = 0;
  public function new() {}
}
