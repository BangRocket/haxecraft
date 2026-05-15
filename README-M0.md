# M0 Foundation — Quickstart

## Prereqs

- Haxe 4.3+
- HashLink 1.16+
- Docker + Docker Compose
- `haxelib install heaps hlsdl utest`
- (MySQL accessed via Haxe stdlib `sys.db.Mysql` — no extra haxelib needed)

## Create an account

```bash
docker compose up -d mysql
./db/apply-migrations.sh
make server-cli
hl out/server-cli.hl create-account joshua hunter2
```

## Run the server

```bash
./run-server.sh
```

Server listens on `127.0.0.1:7777`.

## Run the client

```bash
./run-client.sh
```

A window opens with a login form. Enter the account credentials. On success, "Welcome, <username>" appears.

## Run the test suite

```bash
make test               # shared unit tests
./run-integration.sh    # server + integration tests (requires Docker)
```

## Notes

- MySQL is configured with `mysql_native_password` as the default auth plugin — Haxe's HL MySQL driver speaks the classic protocol and does not support MySQL 8's default `caching_sha2_password`. Changing this requires nuking the volume.
- Plain TCP for M0; **localhost only**. TLS layer goes in before any non-localhost deployment.
- `Std.random` is used for session tokens + password salts — not crypto-grade. Replace with libsodium binding before production.
