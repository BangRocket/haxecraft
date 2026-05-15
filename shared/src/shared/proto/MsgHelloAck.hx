package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgHelloAck implements Serializable {
  public var ok:Bool = false;
  public var reason:String = "";
  public function new() {}
}
