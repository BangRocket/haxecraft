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
    r.addCase(new TestPasswordHash());
    r.addCase(new TestHandoffToken());
    r.addCase(new TestMapData());
    r.addCase(new TestTmxParser());
    r.addCase(new TestTileType());
    r.addCase(new TestItemCatalog());
    r.addCase(new TestItemStack());
    Report.create(r);
    r.run();
  }
}
