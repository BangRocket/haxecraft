package;

import utest.Runner;
import utest.ui.Report;

class TestMain {
  public static function main() {
    var r = new Runner();
    r.addCase(new TestConstants());
    r.addCase(new TestFrameCodec());
    r.addCase(new TestMsgType());
    r.addCase(new TestSerializableMacro());
    r.addCase(new TestMessages());
    Report.create(r);
    r.run();
  }
}
