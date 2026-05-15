package shared.proto;

@:build(shared.proto.SerializableMacro.build())
class MsgMoveIntent implements Serializable {
  public var dir:UInt = 0;  // Direction enum value (0=N, 1=E, 2=S, 3=W)
  public function new() {}
}
