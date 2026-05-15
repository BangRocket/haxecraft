package shared.world;

import haxe.xml.Access;

class TmxParser {
  public static function parse(tmxXml:String):MapData {
    var doc = Xml.parse(tmxXml);
    var root = new Access(doc).node.map;

    var width = Std.parseInt(root.att.width);
    var height = Std.parseInt(root.att.height);
    if (width == null || height == null || width <= 0 || height <= 0) {
      throw "TmxParser: invalid map dimensions";
    }

    // Find the first <layer> with <data encoding="csv">.
    var data:String = null;
    for (layer in root.nodes.layer) {
      if (!layer.hasNode.data) continue;
      var dn = layer.node.data;
      if (dn.has.encoding && dn.att.encoding == "csv") {
        data = dn.innerData;
        break;
      }
    }
    if (data == null) throw "TmxParser: no csv-encoded layer found";

    var tokens = [];
    for (raw in data.split(",")) {
      var t = StringTools.trim(raw);
      if (t.length > 0) tokens.push(t);
    }
    if (tokens.length != width * height) {
      throw 'TmxParser: csv has ${tokens.length} tiles, expected ${width * height}';
    }

    var map = MapData.filled(width, height, TileType.GRASS);
    var i = 0;
    for (y in 0...height) {
      for (x in 0...width) {
        var v = Std.parseInt(tokens[i++]);
        if (v == null) throw 'TmxParser: invalid tile id at (${x},${y})';
        map.setTile(x, y, (v : TileType));
      }
    }
    return map;
  }
}
