package server.zone;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import server.net.ClientConnection;
import shared.proto.MsgAttackTarget;
import shared.proto.MsgCombatEvent;
import shared.proto.MsgType;

/** Combat networking: the attack-target intent and the per-tick swing
    broadcast. Swing resolution itself lives in ZoneSimulator.tick(). */
class CombatHandler {
  var sim:ZoneSimulator;
  var enterHandler:EnterZoneHandler;
  var interest:InterestManager;

  public function new(sim:ZoneSimulator, enterHandler:EnterZoneHandler,
                      interest:InterestManager) {
    this.sim = sim;
    this.enterHandler = enterHandler;
    this.interest = interest;
  }

  /** MsgAttackTarget — set or clear the actor's attackTarget. */
  public function handle(conn:ClientConnection, payload:Bytes):Void {
    var entId = enterHandler.entityIdForConn(conn);
    if (entId == null) return;
    var actor = sim.mobileBySerial(entId);
    if (actor == null) return;
    var req = MsgAttackTarget.deserialize(new BytesInput(payload));
    // Self-attack rejected.
    if (req.targetSerial == actor.serial) return;
    // Zero clears the target (disengage).
    if (req.targetSerial == 0) {
      actor.attackTarget = 0;
      return;
    }
    // Target must be a live mobile this actor can see.
    var target = sim.mobileBySerial(req.targetSerial);
    if (target == null || target.hp <= 0) return;
    if (!interest.knows(actor.serial, req.targetSerial)) return;
    actor.attackTarget = req.targetSerial;
  }

  /** Broadcast every swing the simulator resolved this tick. Call once
      per tick, after sim.tick(). */
  public function broadcastEvents():Void {
    for (e in sim.combatEventsThisTick) {
      var ev = new MsgCombatEvent();
      ev.attackerSerial = e.attacker;
      ev.defenderSerial = e.defender;
      ev.hit = e.hit;
      ev.damage = e.damage;
      ev.defenderHp = e.defenderHp;
      var out = new BytesOutput(); ev.serialize(out);
      var bytes = out.getBytes();
      // Send to every observer who knows either combatant (and to the
      // combatants themselves — the InterestManager treats self as known).
      for (m in sim.allMobiles()) {
        if (m.conn == null || !m.conn.alive) continue;
        if (interest.knows(m.serial, e.attacker) || interest.knows(m.serial, e.defender)) {
          m.conn.sendFrame(MsgType.COMBAT_EVENT, bytes);
        }
      }
    }
  }
}
