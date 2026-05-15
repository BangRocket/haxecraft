package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgError implements Serializable {
  public var code:Int = 0;
  public var message:String = "";
  public function new() {}
}
