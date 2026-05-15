package;

import utest.Assert;
import utest.Test;
import shared.proto.MsgType;

class TestMsgType extends Test {
  function testValuesAreStableAndUnique() {
    Assert.equals(1, (MsgType.HELLO : Int));
    Assert.equals(2, (MsgType.HELLO_ACK : Int));
    Assert.equals(3, (MsgType.LOGIN : Int));
    Assert.equals(4, (MsgType.LOGIN_ACK : Int));
    Assert.equals(5, (MsgType.ERROR : Int));
  }
}
