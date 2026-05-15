package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestConstants());
    r.addCase(new TestFrameCodec());
    Report.create(r);
    r.run();
  }
}
