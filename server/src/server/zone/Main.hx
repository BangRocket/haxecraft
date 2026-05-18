package server.zone;

import server.net.TcpServer;
import server.net.MessageDispatcher;
import server.db.DbClient;
import server.db.CharacterDal;
import server.db.ZoneTileDal;
import shared.Constants;
import shared.proto.MsgType;

class Main {
  public static function main() {
    var db = new DbClient("127.0.0.1", 3306, "haxecraft", "haxecraft", "dev_local_only");
    var characterDal = new CharacterDal(db);
    var tileDal = new ZoneTileDal(db);

    Sys.println("[zone] loading map...");
    var map = MapLoader.loadFromFile("res/maps/starter.tmx");
    Sys.println('[zone] map loaded: ${map.width}x${map.height}');

    // Apply persisted tile edits over the base map.
    var overrides = tileDal.loadOverrides();
    for (o in overrides) {
      map.setTile(o.x, o.y, o.tileType);
      map.setTileData(o.x, o.y, o.data);
    }
    Sys.println('[zone] applied ${overrides.length} persisted tile edits');

    var sim = new ZoneSimulator(map, characterDal, tileDal);
    WorldPopulator.populate(sim);
    Sys.println('[zone] populated: ${sim.worldObjects.length} objects, ${sim.groundItems.length} ground items');
    var enterHandler = new EnterZoneHandler(characterDal, sim);
    var moveHandler = new MoveIntentHandler(sim, enterHandler);
    var inventoryHandler = new InventoryHandler(sim, enterHandler);
    var tileHandler = new TileHandler(sim, enterHandler);
    var craftHandler = new CraftHandler(sim, enterHandler);

    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.ZONE_PORT);
    var dispatcher = new MessageDispatcher();
    dispatcher.register(MsgType.ENTER_ZONE, enterHandler.handle);
    dispatcher.register(MsgType.MOVE_INTENT, moveHandler.handle);
    dispatcher.register(MsgType.SELECT_ACTIVE_ITEM, inventoryHandler.handle);
    dispatcher.register(MsgType.USE_ITEM_ON_TILE, tileHandler.handle);
    dispatcher.register(MsgType.CRAFT, craftHandler.handleCraft);
    dispatcher.register(MsgType.PLACE_FURNITURE, craftHandler.handlePlace);

    var tickInterval = 1.0 / Constants.TICK_HZ;
    var nextTickAt = Sys.time() + tickInterval;

    while (true) {
      srv.tickAccept();
      var i = 0;
      while (i < srv.connections.length) {
        var c = srv.connections[i];
        var frames = c.pollFrames();
        for (f in frames) dispatcher.dispatch(c, f.msgType, f.payload);
        if (!c.alive) {
          var owned = enterHandler.entityIdForConn(c);
          if (owned != null) {
            var ch = sim.entityById(owned);
            if (ch != null) {
              characterDal.savePosition(ch.id, ch.tileX, ch.tileY);
              characterDal.saveInventory(ch.id, ch.inventory.toRows());
              Sys.println('[zone] conn ${c.id} disconnected - saved char ${ch.id} at (${ch.tileX},${ch.tileY})');

              // Broadcast despawn to remaining entities BEFORE removing.
              var dp = new shared.proto.MsgEntityDespawn();
              dp.entityId = owned;
              var dpOut = new haxe.io.BytesOutput(); dp.serialize(dpOut);
              var dpBytes = dpOut.getBytes();
              for (other in sim.allEntities()) {
                if (other.id == owned) continue;
                if (other.conn != null && other.conn.alive) {
                  other.conn.sendFrame(shared.proto.MsgType.ENTITY_DESPAWN, dpBytes);
                }
              }

              sim.despawn(owned);
            }
            enterHandler.forgetConn(c);
          }
          c.close();
          srv.connections.splice(i, 1);
        } else {
          i++;
        }
      }

      var now = Sys.time();
      if (now >= nextTickAt) {
        sim.tick();
        moveHandler.broadcastMoves();
        inventoryHandler.broadcastPickups();
        tileHandler.flush();
        if (sim.shouldFlushNow()) sim.flushPositions();
        nextTickAt += tickInterval;
        if (now > nextTickAt + tickInterval) {
          nextTickAt = now + tickInterval;
        }
      }

      Sys.sleep(0.001);
    }
  }
}
