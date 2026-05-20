package shared.proto;

/** Zone -> broadcast: a single swing resolved. `defenderHp` is the
    defender's post-damage HP so the client doesn't need a separate
    delta message. */
@:build(shared.proto.SerializableMacro.build())
class MsgCombatEvent implements Serializable {
  public var attackerSerial:Int = 0;
  public var defenderSerial:Int = 0;
  public var hit:Bool = false;
  public var damage:Int = 0;
  public var defenderHp:Int = 0;
  public function new() {}
}
