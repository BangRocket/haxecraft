package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestDbClient());
    r.addCase(new TestAccountDal());
    r.addCase(new TestFrameBuffer());
    Report.create(r);
    r.run();
  }
}
