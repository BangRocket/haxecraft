package server.zone;

import sys.io.File;
import shared.world.MapData;
import shared.world.TmxParser;

class MapLoader {
  public static function loadFromFile(path:String):MapData {
    var xml = File.getContent(path);
    return TmxParser.parse(xml);
  }
}
