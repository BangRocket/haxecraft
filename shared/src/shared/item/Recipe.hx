package shared.item;

/** A single craftable recipe: inputs consumed, output produced, at a station. */
class Recipe {
  public var id:Int;
  public var station:CraftStation;
  public var output:ItemType;
  public var outputCount:Int;
  public var inputs:Array<RecipeInput>;

  public function new(id:Int, station:CraftStation, output:ItemType,
      outputCount:Int, inputs:Array<RecipeInput>) {
    this.id = id;
    this.station = station;
    this.output = output;
    this.outputCount = outputCount;
    this.inputs = inputs;
  }
}
