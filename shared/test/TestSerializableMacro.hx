package;

import utest.Assert;
import utest.Test;
import haxe.io.BytesOutput;
import haxe.io.BytesInput;
import _fixtures.TestMsg;

class TestSerializableMacro extends Test {
  function testRoundTrip() {
    var m = new TestMsg();
    m.i = 12345;
    m.s = "hello world";
    m.b = true;
    m.u = 200;

    var out = new BytesOutput();
    m.serialize(out);
    var inp = new BytesInput(out.getBytes());
    var m2 = TestMsg.deserialize(inp);

    Assert.equals(12345, m2.i);
    Assert.equals("hello world", m2.s);
    Assert.isTrue(m2.b);
    Assert.equals(200, m2.u);
  }

  function testEmptyString() {
    var m = new TestMsg();
    m.s = "";
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = TestMsg.deserialize(new BytesInput(out.getBytes()));
    Assert.equals("", m2.s);
  }

  function testFalseBool() {
    var m = new TestMsg();
    m.b = false;
    var out = new BytesOutput();
    m.serialize(out);
    var m2 = TestMsg.deserialize(new BytesInput(out.getBytes()));
    Assert.isFalse(m2.b);
  }
}
