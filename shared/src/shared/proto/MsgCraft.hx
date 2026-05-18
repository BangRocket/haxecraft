package shared.proto;

/** Client -> server: craft the recipe with this id (at a nearby station). */
@:build(shared.proto.SerializableMacro.build())
class MsgCraft implements Serializable {
  public var recipeId:Int = 0;
  public function new() {}
}
