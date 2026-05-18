package shared.proto;

import haxe.io.BytesOutput;
import haxe.io.Input;

/** Server -> client: the player's full inventory. Hand-coded codec — the
    SerializableMacro does not support variable-length arrays. */
class MsgInventory {
  public var activeSlot:Int = 0;
  public var slots:Array<{itemTypeId:Int, count:Int}> = [];

  public function new() {}

  public function serialize(out:BytesOutput):Void {
    out.writeInt32(activeSlot);
    out.writeUInt16(slots.length);
    for (s in slots) {
      out.writeInt32(s.itemTypeId);
      out.writeInt32(s.count);
    }
  }

  public static function deserialize(inp:Input):MsgInventory {
    var m = new MsgInventory();
    m.activeSlot = inp.readInt32();
    var n = inp.readUInt16();
    for (_ in 0...n) {
      m.slots.push({ itemTypeId: inp.readInt32(), count: inp.readInt32() });
    }
    return m;
  }
}
