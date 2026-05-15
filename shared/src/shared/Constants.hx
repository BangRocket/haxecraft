package shared;

class Constants {
  public static inline var PROTOCOL_VERSION:Int = 1;
  public static inline var MAX_FRAME_SIZE:Int = 65535;
  public static inline var TICK_HZ:Int = 10;
  public static inline var DEFAULT_SERVER_PORT:Int = 7777;
  public static inline var ZONE_PORT:Int = 7778;
  public static inline var DEFAULT_SERVER_HOST:String = "127.0.0.1";

  // M1 world dimensions
  public static inline var MAP_W:Int = 1024;
  public static inline var MAP_H:Int = 1024;
  public static inline var DEFAULT_SPAWN_X:Int = 512;
  public static inline var DEFAULT_SPAWN_Y:Int = 512;

  // Movement: a tile-step costs MOVE_TICKS server ticks (10 Hz). 2 ticks = 5 tiles/sec.
  public static inline var MOVE_TICKS:Int = 2;

  // Handoff token signing — M1 uses a hardcoded dev secret.
  // Replace with an env-var or config-file read before any non-localhost use.
  public static inline var HANDOFF_SECRET:String = "m1-dev-only-handoff-secret-change-me";
  public static inline var HANDOFF_TTL_SECONDS:Int = 30;
}
