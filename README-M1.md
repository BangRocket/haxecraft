# M1 Zone — Eyes-On Test Guide

Manual verification of the M1 milestone. The headless integration test
(`TestZoneLifecycle`) already exercises the full walk → logout → login flow
end-to-end; this guide walks a human through the same flow with eyes on the
client. Verifies DoD items #4 (world renders, WASD moves) and #5 (position
persists across logout).

## What you'll verify

- [ ] Client opens, login succeeds, the world renders after a brief "Connecting
      to zone…" transition.
- [ ] WASD (or arrow keys) move the player one tile per server tick (100 ms).
      Movement is rejected on non-walkable tiles (water, stone, rock, tree).
- [ ] Close the client window, reopen it, log in with the same account — the
      player respawns at the last tile you stood on.

## Prereqs

See `README-M0.md` for the full prereq list (Haxe 4.3+, HashLink 1.16+, Docker
Compose, haxelib packages). M1-specific things on top:

- ~5 MB more disk for `res/maps/starter.tmx`.
- The zone binary parses the 1024×1024 TMX at startup; expect a **~30 s pause**
  before the zone reports listening on `7778`. Gateway is up immediately on
  `7777`.

## One-time setup

```bash
# 1. MySQL up + migrations (idempotent; safe to re-run).
docker compose up -d mysql
./db/apply-migrations.sh
# Applies 0001_accounts.sql and 0002_characters.sql.

# 2. Build everything.
make all
# Produces: out/{gateway,zone,server-cli,client,shared-test,worldgen-tmx}.hl

# 3. Create a test account.
hl out/server-cli.hl create-account tester hunter2
# → "created account id=1 username=tester"
```

A character row is **auto-created on first login** — no separate step.

## Launch

Two terminals.

**Terminal 1 — server:**

```bash
./run-server.sh
```

Watch for these lines in order:

```
[server] listening on 127.0.0.1:7777    ← gateway, immediate
[zone] loading map...                   ← zone starts; takes ~30 s
[zone] map loaded: 1024x1024
[server] listening on 127.0.0.1:7778    ← zone ready
```

Wait for the zone to print `listening` before launching the client.

**Terminal 2 — client:**

```bash
./run-client.sh
```

A Heaps window opens with a login form.

## The eyes-on flow

1. **Login.** Enter `tester` / `hunter2`. Hit enter or click Login.
2. **Connecting screen.** "Connecting to zone…" appears briefly (one round-trip:
   gateway issues a handoff token, client opens a second TCP connection to the
   zone on `7778`).
3. **World renders.** Solid-color squares per tile type centered on your player:
   - **Green** = grass (walkable)
   - **Tan** = sand (walkable)
   - **Blue** = water (blocked)
   - **Light gray** = stone (blocked)
   - **Dark gray** = rock (blocked)
   - **Dark green** = tree (blocked)

   **Your player is the red square.** Other connected entities, if any, render
   as yellow squares with interpolated movement.

4. **Walk.** Press W/A/S/D or the arrow keys. Each press queues one
   `MoveIntent`; the server validates against the map at 10 Hz and broadcasts
   the result. Expect stepwise tile-by-tile motion. Walking into a non-walkable
   tile produces no movement (intent rejected).

5. **Walk far enough to remember the spot.** A few tiles in any direction is
   fine — note the rough screen position.

6. **Logout.** Close the client window. The zone logs:

   ```
   [zone] conn N disconnected - saved char K at (tileX,tileY)
   ```

   Even without that log line, the zone flushes positions to the DB every 5 s
   automatically.

7. **Log back in.** Re-run `./run-client.sh`, log in with the same credentials.

8. **Verify.** After the connecting transition, your red square should appear
   at the same tile you stood on. If yes — M1 DoD #4 + #5 pass.

## Troubleshooting

**`run-server.sh` fails with "port is already allocated" on 3306.**
Another worktree's MySQL container is holding the port. Either stop it
(`docker compose stop mysql` from the other worktree) or override the host
port: edit `docker-compose.yml` to publish `${MYSQL_HOST_PORT:-3306}:3306` and
set `MYSQL_HOST_PORT` in a `.env` per worktree.

**Client hangs at "Connecting to zone…" forever.**
Zone hasn't bound to 7778 yet. Check Terminal 1 for `[zone] map loaded` /
`listening on 127.0.0.1:7778`. The TMX parse takes ~30 s; if it's stalled
beyond that, look for an error after `[zone] loading map...` in the server
log.

**Player doesn't move when pressing keys.**
Check the client window has focus (Heaps windows occasionally lose focus on
macOS). If movement still fails, look at the zone log — `MoveIntentHandler`
prints rejection reasons when an intent is invalid.

**Login fails with "wrong password" but you're sure it's right.**
Account passwords are hashed; if the DB volume was nuked between
`create-account` and now, the account is gone. Re-run
`hl out/server-cli.hl create-account tester hunter2`.

## Reset between tests

```bash
# Wipe character positions but keep accounts:
docker compose exec -T mysql mysql -uhaxecraft -pdev_local_only haxecraft \
  -e "TRUNCATE TABLE characters"

# Or nuke everything (re-applies migrations on next run-server):
docker compose down -v
```

## Cleanup

```bash
docker compose stop     # keep volume + accounts
# or
docker compose down -v  # delete the DB volume entirely
```
