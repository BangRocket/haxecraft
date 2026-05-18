package shared.proto;

/** Client -> server: place the active furniture item at (tileX, tileY). */
@:build(shared.proto.SerializableMacro.build())
class MsgPlaceFurniture implements Serializable {
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public function new() {}
}
