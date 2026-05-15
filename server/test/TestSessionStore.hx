package;

import utest.Assert;
import utest.Test;
import server.auth.SessionStore;

class TestSessionStore extends Test {
  function testMintAndLookup() {
    var store = new SessionStore();
    var tok = store.mint(42);
    Assert.notNull(tok);
    Assert.isTrue(tok.length >= 16);
    Assert.equals(42, store.accountIdFor(tok));
  }

  function testUnknownTokenReturnsNull() {
    var store = new SessionStore();
    Assert.isNull(store.accountIdFor("nope"));
  }

  function testTokensAreUnique() {
    var store = new SessionStore();
    var t1 = store.mint(1);
    var t2 = store.mint(1);
    Assert.notEquals(t1, t2);
  }
}
