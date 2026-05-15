package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgLoginAck implements Serializable {
  public var success:Bool = false;
  public var sessionToken:String = "";
  public var errorMsg:String = "";
  public function new() {}
}
