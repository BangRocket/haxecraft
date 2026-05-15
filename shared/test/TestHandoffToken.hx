package;

import utest.Assert;
import utest.Test;
import shared.security.HandoffToken;

class TestHandoffToken extends Test {
  function testRoundTripAccepts() {
    var tok = HandoffToken.mint(42, 7, 60);
    var parsed = HandoffToken.verify(tok);
    Assert.notNull(parsed);
    Assert.equals(42, parsed.accountId);
    Assert.equals(7, parsed.characterId);
  }

  function testTamperedRejected() {
    var tok = HandoffToken.mint(42, 7, 60);
    // Flip a char in the body
    var muted = tok.charAt(0) == "x" ? "y" + tok.substr(1) : "x" + tok.substr(1);
    Assert.isNull(HandoffToken.verify(muted));
  }

  function testExpiredRejected() {
    var tok = HandoffToken.mint(42, 7, -1);  // expiry one second in the past
    Assert.isNull(HandoffToken.verify(tok));
  }

  function testMalformedRejected() {
    Assert.isNull(HandoffToken.verify(""));
    Assert.isNull(HandoffToken.verify("not-a-token"));
    Assert.isNull(HandoffToken.verify("1|2|3"));
  }
}
