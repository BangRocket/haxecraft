package server.zone;

/** A scheduled callback. The object is its own cancellation handle. */
class ScheduledTimer {
  public var fireTick:Int;
  public var intervalTicks:Int;   // 0 = one-shot; > 0 = recurring
  public var callback:Void -> Void;
  public var cancelled:Bool = false;

  public function new(fireTick:Int, intervalTicks:Int, callback:Void -> Void) {
    this.fireTick = fireTick;
    this.intervalTicks = intervalTicks;
    this.callback = callback;
  }
}
