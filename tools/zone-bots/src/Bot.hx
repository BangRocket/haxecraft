import shared.world.Direction;
import shared.proto.ChatChannel;

/**
 * One headless bot. Connects through the gateway, enters the zone, then
 * loops a weighted-random behaviour — wander / chat / gather — until its
 * deadline. Any failure is recorded and ends the run cleanly.
 */
class Bot {
  public var name:String;
  public var actions:Int = 0;
  public var error:String = null;

  var client:HeadlessClient;
  var rng:Int;

  public function new(name:String, seed:Int) {
    this.name = name;
    this.rng = seed;
  }

  public function run(username:String, password:String, durationS:Float):Void {
    try {
      client = new HeadlessClient();
      client.connectGateway();
      if (!client.login(username, password)) { error = "login rejected"; return; }
      client.enterZone();
      var deadline = haxe.Timer.stamp() + durationS;
      while (haxe.Timer.stamp() < deadline) {
        step();
        Sys.sleep(0.25);
      }
      client.close();
    } catch (e:Dynamic) {
      error = Std.string(e);
      try { if (client != null) client.close(); } catch (_:Dynamic) {}
    }
  }

  function step():Void {
    var roll = nextInt(100);
    if (roll < 65) {
      client.move(randomDir());
    } else if (roll < 80) {
      client.sendChat((ChatChannel.SAY : Int), 'bot $name wandering');
    } else {
      client.selectActiveSlot(nextInt(4));         // a wood tool
      client.useItemOnTile(client.tileX + 1, client.tileY);
    }
    actions++;
  }

  function randomDir():Direction {
    return switch nextInt(4) {
      case 0: Direction.NORTH;
      case 1: Direction.EAST;
      case 2: Direction.SOUTH;
      default: Direction.WEST;
    }
  }

  /** Tiny deterministic LCG so each bot's behaviour is reproducible. */
  function nextInt(n:Int):Int {
    rng = rng * 1664525 + 1013904223;
    return (rng & 0x7fffffff) % n;
  }
}
