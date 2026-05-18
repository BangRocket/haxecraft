package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestDbClient());
    r.addCase(new TestAccountDal());
    r.addCase(new TestCharacterDal());
    r.addCase(new TestZoneSimulator());
    r.addCase(new TestWorldPopulator());
    r.addCase(new TestInventory());
    r.addCase(new TestTileInteraction());
    r.addCase(new TestFrameBuffer());
    r.addCase(new TestSessionStore());
    r.addCase(new TestLoginFlow());
    r.addCase(new TestZoneLifecycle());
    Report.create(r);
    r.run();
  }
}
