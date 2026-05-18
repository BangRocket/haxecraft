package shared.proto;

/** Client -> server: use the active item on the tile at (tileX, tileY). */
@:build(shared.proto.SerializableMacro.build())
class MsgUseItemOnTile implements Serializable {
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public function new() {}
}
