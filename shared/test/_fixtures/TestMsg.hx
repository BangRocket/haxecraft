package _fixtures;

@:build(shared.proto.SerializableMacro.build())
class TestMsg implements shared.proto.Serializable {
  public var i:Int = 0;
  public var s:String = "";
  public var b:Bool = false;
  public var u:UInt = 0;
  public function new() {}
}
