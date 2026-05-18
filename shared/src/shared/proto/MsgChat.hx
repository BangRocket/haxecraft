package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgChat implements Serializable {
  public var channel:Int = 0;     // a ChatChannel value
  public var senderName:String = "";  // empty client->server; server fills it
  public var text:String = "";
  public function new() {}
}
