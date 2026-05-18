package;

import utest.Assert;
import utest.Test;
import server.zone.ZoneSimulator;
import server.zone.Character;
import server.zone.WorldObject;
import server.zone.Crafting;
import shared.world.MapData;
import shared.world.TileType;
import shared.item.ItemType;

class TestCrafting extends Test {
  function makeActor(sim:ZoneSimulator):Character {
    var ch = new Character(1, "a", null, 4, 4);
    sim.spawn(ch);
    return ch;
  }

  function testCraftRequiresAStation() {
    var sim = new ZoneSimulator(MapData.filled(8, 8, TileType.GRASS));
    var ch = makeActor(sim);
    ch.inventory.add(ItemType.WOOD, 50);
    Assert.isFalse(Crafting.craft(sim, ch, 1));  // recipe 1 needs a workbench
  }

  function testCraftConsumesInputsAndProducesOutput() {
    var sim = new ZoneSimulator(MapData.filled(8, 8, TileType.GRASS));
    var ch = makeActor(sim);
    ch.inventory.add(ItemType.WOOD, 50);
    sim.addWorldObject(new WorldObject(1, ItemType.WORKBENCH, 5, 4));  // adjacent
    Assert.isTrue(Crafting.craft(sim, ch, 1));            // workbench <- wood 20
    Assert.isTrue(ch.inventory.has(ItemType.WORKBENCH, 1));
    Assert.isTrue(ch.inventory.has(ItemType.WOOD, 30));   // 50 - 20
  }

  function testCraftFailsWithoutEnoughResources() {
    var sim = new ZoneSimulator(MapData.filled(8, 8, TileType.GRASS));
    var ch = makeActor(sim);
    ch.inventory.add(ItemType.WOOD, 5);
    sim.addWorldObject(new WorldObject(1, ItemType.WORKBENCH, 5, 4));
    Assert.isFalse(Crafting.craft(sim, ch, 1));
    Assert.isTrue(ch.inventory.has(ItemType.WOOD, 5));    // unchanged
  }

  function testPlaceFurnitureConsumesAndPlaces() {
    var sim = new ZoneSimulator(MapData.filled(8, 8, TileType.GRASS));
    var ch = makeActor(sim);
    ch.inventory.add(ItemType.CHEST, 1);
    ch.inventory.activeSlot = 0;
    var obj = Crafting.place(sim, ch, 5, 4);
    Assert.notNull(obj);
    Assert.equals(1, sim.worldObjects.length);
    Assert.isFalse(ch.inventory.has(ItemType.CHEST, 1));  // consumed
  }

  function testPlaceFailsOnOccupiedTile() {
    var sim = new ZoneSimulator(MapData.filled(8, 8, TileType.GRASS));
    var ch = makeActor(sim);
    ch.inventory.add(ItemType.CHEST, 1);
    ch.inventory.activeSlot = 0;
    sim.addWorldObject(new WorldObject(9, ItemType.OVEN, 5, 4));  // tile taken
    Assert.isNull(Crafting.place(sim, ch, 5, 4));
  }
}
