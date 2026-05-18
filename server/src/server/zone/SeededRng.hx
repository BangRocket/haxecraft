package server.zone;

/** Tiny deterministic LCG. The same seed always yields the same sequence,
    so world population is reproducible (and testable). */
class SeededRng {
  var state:Int;

  public function new(seed:Int) {
    this.state = seed;
  }

  /** A non-negative Int in [0, n). */
  public function nextInt(n:Int):Int {
    // Numerical Recipes LCG constants; Int overflow wraps, which is fine.
    state = state * 1664525 + 1013904223;
    return (state & 0x7fffffff) % n;
  }

  /** An Int in [lo, hi] inclusive. */
  public function range(lo:Int, hi:Int):Int {
    return lo + nextInt(hi - lo + 1);
  }
}
