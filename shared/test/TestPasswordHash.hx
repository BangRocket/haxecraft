package;

import utest.Assert;
import utest.Test;
import shared.security.PasswordHash;

class TestPasswordHash extends Test {
  function testHashIsNotPlaintext() {
    var h = PasswordHash.hash("hunter2");
    Assert.notEquals("hunter2", h);
    Assert.isTrue(h.length > 20);
  }

  function testCorrectPasswordVerifies() {
    var h = PasswordHash.hash("hunter2");
    Assert.isTrue(PasswordHash.verify("hunter2", h));
  }

  function testWrongPasswordRejected() {
    var h = PasswordHash.hash("hunter2");
    Assert.isFalse(PasswordHash.verify("Hunter2", h));
    Assert.isFalse(PasswordHash.verify("", h));
    Assert.isFalse(PasswordHash.verify("hunter22", h));
  }

  function testTwoHashesOfSamePasswordDiffer() {
    var h1 = PasswordHash.hash("hunter2");
    var h2 = PasswordHash.hash("hunter2");
    Assert.notEquals(h1, h2);  // salts differ
    Assert.isTrue(PasswordHash.verify("hunter2", h1));
    Assert.isTrue(PasswordHash.verify("hunter2", h2));
  }
}
