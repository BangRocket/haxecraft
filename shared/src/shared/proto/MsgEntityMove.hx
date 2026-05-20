package shared.proto;

/** Server -> client: an entity moved. Two forms share the same message:

      - Tile step (existing): `from*`/`to*` filled, `durationMs > 0`,
        `newParentSerial = 0`. The entity walks from world tile to world tile.

      - Re-parent (new): `newParentSerial != 0` means the item moved into
        the named mobile's inventory at `newSlot`. `newParentSerial = 0`
        AND `from*`/`to*` filled means the item went from a parent back
        out into the world at `to*`. */
@:build(shared.proto.SerializableMacro.build())
class MsgEntityMove implements Serializable {
  public var entityId:Int = 0;
  public var fromX:Int = 0;
  public var fromY:Int = 0;
  public var toX:Int = 0;
  public var toY:Int = 0;
  public var durationMs:Int = 0;
  public var newParentSerial:Int = 0;
  public var newSlot:Int = 0;
  public function new() {}
}
