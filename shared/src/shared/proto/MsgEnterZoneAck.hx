package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgEnterZoneAck implements Serializable {
  public var success:Bool = false;
  public var errorMsg:String = "";
  public var entityId:Int = 0;
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public function new() {}
}
