package;

import utest.Assert;
import utest.Test;
import server.zone.ZoneSimulator;
import server.zone.Character;
import server.zone.TileInteraction;
import shared.world.MapData;
import shared.world.TileType;
import shared.item.ItemType;

class TestTileInteraction extends Test {
  function actor(sim:ZoneSimulator, item:ItemType):Character {
    var ch = new Character(1, "a", null, 1, 1);
    ch.inventory.add(item, 9);
    ch.inventory.activeSlot = 0;
    sim.spawn(ch);
    return ch;
  }

  function testGemAxeFellsTreeInOneHit() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.TREE);
    var sim = new ZoneSimulator(map);
    var ch = actor(sim, ItemType.GEM_AXE);  // dmg 30-39 >= 20 threshold
    Assert.isTrue(TileInteraction.apply(sim, ch, 2, 1));
    Assert.equals((TileType.GRASS : Int), sim.map.tileAt(2, 1));
  }

  function testWrongToolDoesNothing() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.TREE);
    var sim = new ZoneSimulator(map);
    var ch = actor(sim, ItemType.GEM_PICKAXE);  // pickaxe can't chop a tree
    Assert.isFalse(TileInteraction.apply(sim, ch, 2, 1));
    Assert.equals((TileType.TREE : Int), sim.map.tileAt(2, 1));
  }

  function testHoeTurnsGrassToFarmland() {
    var sim = new ZoneSimulator(MapData.filled(4, 4, TileType.GRASS));
    var ch = actor(sim, ItemType.WOOD_HOE);
    Assert.isTrue(TileInteraction.apply(sim, ch, 2, 1));
    Assert.equals((TileType.FARMLAND : Int), sim.map.tileAt(2, 1));
  }

  function testPlantSeedsConsumesAndGrowsWheat() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.FARMLAND);
    var sim = new ZoneSimulator(map);
    var ch = actor(sim, ItemType.SEEDS);
    Assert.isTrue(TileInteraction.apply(sim, ch, 2, 1));
    Assert.equals((TileType.WHEAT : Int), sim.map.tileAt(2, 1));
    Assert.isTrue(ch.inventory.has(ItemType.SEEDS, 8));   // one of nine consumed
  }

  function testMiningRockTakesSeveralHits() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.ROCK);
    var sim = new ZoneSimulator(map);
    var ch = actor(sim, ItemType.WOOD_PICKAXE);  // dmg 10-19, threshold 50
    TileInteraction.apply(sim, ch, 2, 1);
    Assert.equals((TileType.ROCK : Int), sim.map.tileAt(2, 1));  // survives the first hit
    for (_ in 0...6) TileInteraction.apply(sim, ch, 2, 1);
    Assert.equals((TileType.DIRT : Int), sim.map.tileAt(2, 1));  // 7 hits >= 50 damage
  }

  function testFlowerDropsTwoFlowers() {
    var map = MapData.filled(4, 4, TileType.GRASS);
    map.setTile(2, 1, TileType.FLOWER);
    var sim = new ZoneSimulator(map);
    var ch = actor(sim, ItemType.WOOD_SHOVEL);
    Assert.isTrue(TileInteraction.apply(sim, ch, 2, 1));
    Assert.equals((TileType.GRASS : Int), sim.map.tileAt(2, 1));
    Assert.equals(1, sim.groundItems.length);
    Assert.equals((ItemType.FLOWER : Int), (sim.groundItems[0].itemType : Int));
    Assert.equals(2, sim.groundItems[0].count);
  }
}
