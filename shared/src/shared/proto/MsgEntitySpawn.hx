package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgEntitySpawn implements Serializable {
  public var entityId:Int = 0;
  public var name:String = "";
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public function new() {}
}
