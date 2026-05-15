package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgEnterZone implements Serializable {
  public var handoffToken:String = "";
  public function new() {}
}
