package shared.proto;

/** Client -> zone: select an attack target (or 0 to disengage). */
@:build(shared.proto.SerializableMacro.build())
class MsgAttackTarget implements Serializable {
  public var targetSerial:Int = 0;
  public function new() {}
}
