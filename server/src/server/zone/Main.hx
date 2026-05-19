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
    var interest = new InterestManager();
    WorldPopulator.populate(sim);
    Sys.println('[zone] populated: ${sim.worldObjects.length} objects, ${sim.groundItems.length} ground items');
    var enterHandler = new EnterZoneHandler(characterDal, sim);
    var moveHandler = new MoveIntentHandler(sim, enterHandler, interest);
    var chatHandler = new ChatHandler(sim, enterHandler, interest);
    var inventoryHandler = new InventoryHandler(sim, enterHandler);
    var tileHandler = new TileHandler(sim, enterHandler);
    var craftHandler = new CraftHandler(sim, enterHandler);

    var srv = new TcpServer(Constants.DEFAULT_SERVER_HOST, Constants.ZONE_PORT);
    var dispatcher = new MessageDispatcher();
    dispatcher.register(MsgType.ENTER_ZONE, enterHandler.handle);
    dispatcher.register(MsgType.MOVE_INTENT, moveHandler.handle);
    dispatcher.register(MsgType.CHAT, chatHandler.handle);
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
              try {
                characterDal.savePosition(ch.id, ch.tileX, ch.tileY);
                characterDal.saveInventory(ch.id, ch.inventory.toRows());
              } catch (err:Dynamic) {
                Sys.println('[zone] disconnect save failed for char ${ch.id}: $err');
              }
              Sys.println('[zone] conn ${c.id} disconnected - saved char ${ch.id} at (${ch.tileX},${ch.tileY})');

              // Despawn for every observer that currently knows this entity.
              var dp = new shared.proto.MsgEntityDespawn();
              dp.entityId = owned;
              var dpOut = new haxe.io.BytesOutput(); dp.serialize(dpOut);
              var dpBytes = dpOut.getBytes();
              for (obsId in interest.forget(owned)) {
                var obs = sim.entityById(obsId);
                if (obs != null && obs.conn != null && obs.conn.alive) {
                  obs.conn.sendFrame(shared.proto.MsgType.ENTITY_DESPAWN, dpBytes);
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
        var entityList = [for (e in sim.allEntities()) e];
        broadcastInterestDiffs(sim, interest.update(entityList));
        nextTickAt += tickInterval;
        if (now > nextTickAt + tickInterval) {
          nextTickAt = now + tickInterval;
        }
      }

      Sys.sleep(0.001);
    }
  }

  static function broadcastInterestDiffs(sim:ZoneSimulator, diffs:Array<InterestDiff>):Void {
    for (d in diffs) {
      var observer = sim.entityById(d.observerId);
      if (observer == null || observer.conn == null || !observer.conn.alive) continue;
      for (id in d.entered) {
        var e = sim.entityById(id);
        if (e == null) continue;
        var sp = new shared.proto.MsgEntitySpawn();
        sp.entityId = e.id;
        sp.name = e.name;
        sp.tileX = e.tileX;
        sp.tileY = e.tileY;
        var o = new haxe.io.BytesOutput(); sp.serialize(o);
        observer.conn.sendFrame(shared.proto.MsgType.ENTITY_SPAWN, o.getBytes());
      }
      for (id in d.left) {
        var dp = new shared.proto.MsgEntityDespawn();
        dp.entityId = id;
        var o = new haxe.io.BytesOutput(); dp.serialize(o);
        observer.conn.sendFrame(shared.proto.MsgType.ENTITY_DESPAWN, o.getBytes());
      }
    }
  }
}
