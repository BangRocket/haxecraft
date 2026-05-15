package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgLogin implements Serializable {
  public var username:String = "";
  public var password:String = "";
  public function new() {}
}
