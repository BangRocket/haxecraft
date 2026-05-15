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
    Assert.equals(10, (MsgType.ZONE_HANDOFF : Int));
    Assert.equals(11, (MsgType.ENTER_ZONE : Int));
    Assert.equals(12, (MsgType.ENTER_ZONE_ACK : Int));
    Assert.equals(20, (MsgType.MOVE_INTENT : Int));
    Assert.equals(21, (MsgType.ENTITY_SPAWN : Int));
    Assert.equals(22, (MsgType.ENTITY_MOVE : Int));
    Assert.equals(23, (MsgType.ENTITY_DESPAWN : Int));
  }
}
