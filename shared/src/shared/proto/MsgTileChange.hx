package shared.proto;

/** Server -> client: a tile changed type and/or per-tile data. */
@:build(shared.proto.SerializableMacro.build())
class MsgTileChange implements Serializable {
  public var tileX:Int = 0;
  public var tileY:Int = 0;
  public var tileType:Int = 0;
  public var data:Int = 0;
  public function new() {}
}
