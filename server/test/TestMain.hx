package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestDbClient());
    r.addCase(new TestAccountDal());
    r.addCase(new TestZoneTileDal());
    r.addCase(new TestZoneSimulator());
    r.addCase(new TestInterestManager());
    r.addCase(new TestScheduler());
    r.addCase(new TestSerials());
    r.addCase(new TestItem());
    r.addCase(new TestWorldPopulator());
    r.addCase(new TestZoneBoot());
    r.addCase(new TestSectorGrid());
    r.addCase(new TestCombat());
    r.addCase(new TestHpRegen());
    r.addCase(new TestInventory());
    r.addCase(new TestTileInteraction());
    r.addCase(new TestCrafting());
    r.addCase(new TestFrameBuffer());
    r.addCase(new TestSessionStore());
    r.addCase(new TestLoginFlow());
    r.addCase(new TestZoneLifecycle());
    r.addCase(new TestZoneInterest());
    r.addCase(new TestZoneChat());
    r.addCase(new TestZoneCombat());
    Report.create(r);
    r.run();
  }
}
