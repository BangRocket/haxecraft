package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgHello implements Serializable {
  public var protocolVersion:Int = 0;
  public var buildHash:String = "";
  public function new() {}
}
