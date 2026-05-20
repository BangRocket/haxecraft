package;

import utest.Assert;
import utest.Test;
import server.zone.Sector;
import server.zone.SectorGrid;
import server.zone.Mobile;
import server.zone.Item;
import shared.item.ItemType;

class TestSectorGrid extends Test {
  function testMobileAddAndLookup() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 12, 9);
    g.addMobile(m);
    Assert.equals(m, g.mobileAt(12, 9));
    Assert.isNull(g.mobileAt(13, 9));
  }

  function testMobileMoveSameSector() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 0, 0);
    g.addMobile(m);
    g.moveMobile(m, 0, 0, 7, 7);   // both within sector (0,0)
    m.tileX = 7; m.tileY = 7;
    Assert.isNull(g.mobileAt(0, 0));
    Assert.equals(m, g.mobileAt(7, 7));
  }

  function testMobileMoveAcrossSectorBoundary() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 7, 0);     // sector (0,0)
    g.addMobile(m);
    g.moveMobile(m, 7, 0, 8, 0);                // sector (1,0)
    m.tileX = 8; m.tileY = 0;
    Assert.isNull(g.mobileAt(7, 0));
    Assert.equals(m, g.mobileAt(8, 0));
  }

  function testMobileRemove() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 5, 5);
    g.addMobile(m);
    g.removeMobile(m.serial);
    Assert.isNull(g.mobileAt(5, 5));
  }

  function testItemAddAndBlocking() {
    var g = new SectorGrid(64, 64);
    var bench = new Item(0x40000001, ItemType.WORKBENCH, 1);
    bench.tileX = 10; bench.tileY = 10;
    var wood = new Item(0x40000002, ItemType.WOOD, 3);
    wood.tileX = 12; wood.tileY = 10;
    g.addItem(bench);
    g.addItem(wood);

    Assert.equals(bench, g.itemAt(10, 10));
    Assert.equals(wood, g.itemAt(12, 10));
    Assert.isTrue(g.blockingItemAt(10, 10));      // furniture blocks
    Assert.isFalse(g.blockingItemAt(12, 10));     // resource doesn't
  }

  function testItemRemove() {
    var g = new SectorGrid(64, 64);
    var w = new Item(0x40000001, ItemType.WOOD, 1);
    w.tileX = 3; w.tileY = 3;
    g.addItem(w);
    g.removeItem(w.serial);
    Assert.isNull(g.itemAt(3, 3));
    Assert.isFalse(g.blockingItemAt(3, 3));
  }

  function testSameTileMobileAndItem() {
    var g = new SectorGrid(64, 64);
    var m = new Mobile(1, "a", null, 4, 4);
    var w = new Item(0x40000001, ItemType.WOOD, 1);
    w.tileX = 4; w.tileY = 4;
    g.addMobile(m);
    g.addItem(w);
    Assert.equals(m, g.mobileAt(4, 4));
    Assert.equals(w, g.itemAt(4, 4));
  }

  function testSectorsInRangeCoversNeighborhood() {
    var g = new SectorGrid(128, 128);
    // A center at tile (40,40) is in sector (5,5). A tile radius of 10
    // gives a sector radius of ceil(10/8) = 2, so the 5x5 sector window
    // (sx 3..7, sy 3..7) = 25 sectors.
    var seen = new Map<Int, Bool>();
    for (sec in g.sectorsInRange(40, 40, 10)) {
      var key = sec.sy * 1000 + sec.sx;
      Assert.isFalse(seen.exists(key));    // no duplicates
      seen.set(key, true);
    }
    var count = 0;
    for (_ in seen.keys()) count++;
    Assert.equals(25, count);
  }

  function testSectorsInRangeClampsAtMapEdge() {
    var g = new SectorGrid(64, 64);
    // Center at (0,0) with radius 8 wants sectors (-1,-1)..(1,1) but
    // clamps to (0,0)..(1,1) = 4 sectors.
    var n = 0;
    for (_ in g.sectorsInRange(0, 0, 8)) n++;
    Assert.equals(4, n);
  }

  function testMobileAtOffMapReturnsNull() {
    var g = new SectorGrid(64, 64);
    Assert.isNull(g.mobileAt(-1, 0));
    Assert.isNull(g.mobileAt(64, 0));
    Assert.isNull(g.mobileAt(0, 999));
  }
}
