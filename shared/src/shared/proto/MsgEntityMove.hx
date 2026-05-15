package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgEntityMove implements Serializable {
  public var entityId:Int = 0;
  public var fromX:Int = 0;
  public var fromY:Int = 0;
  public var toX:Int = 0;
  public var toY:Int = 0;
  public var durationMs:Int = 0;
  public function new() {}
}
