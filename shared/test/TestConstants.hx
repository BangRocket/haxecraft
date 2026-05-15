package;

import utest.Assert;
import utest.Test;
import shared.Constants;

class TestConstants extends Test {
  function testProtocolVersionIsPositive() {
    Assert.isTrue(Constants.PROTOCOL_VERSION > 0);
  }
  function testMaxFrameSizeIs64K() {
    Assert.equals(65535, Constants.MAX_FRAME_SIZE);
  }
  function testTickHz() {
    Assert.equals(10, Constants.TICK_HZ);
  }
  function testDefaultServerPort() {
    Assert.equals(7777, Constants.DEFAULT_SERVER_PORT);
  }
}
