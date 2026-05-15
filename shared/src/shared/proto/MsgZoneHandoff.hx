package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgZoneHandoff implements Serializable {
  public var zoneHost:String = "";
  public var zonePort:Int = 0;
  public var handoffToken:String = "";
  public function new() {}
}
